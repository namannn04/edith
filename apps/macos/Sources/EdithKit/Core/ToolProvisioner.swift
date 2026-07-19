import Combine
import Foundation

public struct CLICommandRequest: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let environment: [String: String]

    public init(executableURL: URL, arguments: [String], environment: [String: String]) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
    }
}

public struct CLICommandResult: Equatable, Sendable {
    public let terminationStatus: Int32
    public let output: String

    public init(terminationStatus: Int32, output: String) {
        self.terminationStatus = terminationStatus
        self.output = output
    }
}

public enum CLIToolProvisionState: Equatable, Sendable {
    case idle
    case checking
    case present(version: String)
    case installing(logTail: [String])
    case installed
    case failed(message: String, instruction: String)
}

private final class CLIStreamingOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = ""
    private var complete = ""

    func receive(_ data: Data) -> [String] {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return [] }
        lock.lock()
        defer { lock.unlock() }
        complete += text
        pending += text.replacingOccurrences(of: "\r", with: "\n")
        var lines: [String] = []
        while let newline = pending.firstIndex(of: "\n") {
            let line = String(pending[..<newline])
            pending.removeSubrange(...newline)
            if !line.isEmpty { lines.append(line) }
        }
        return lines
    }

    func finish() -> (lines: [String], output: String) {
        lock.lock()
        defer { lock.unlock() }
        let lines = pending.isEmpty ? [] : [pending]
        pending = ""
        return (lines, complete)
    }
}

public enum CLICommandRunner {
    public static func run(
        _ request: CLICommandRequest,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> CLICommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            let output = CLIStreamingOutput()
            process.executableURL = request.executableURL
            process.arguments = request.arguments
            process.environment = request.environment
            process.standardOutput = pipe
            process.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { handle in
                for line in output.receive(handle.availableData) { onLine(line) }
            }
            process.terminationHandler = { completedProcess in
                pipe.fileHandleForReading.readabilityHandler = nil
                let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
                for line in output.receive(remaining) { onLine(line) }
                let finished = output.finish()
                for line in finished.lines { onLine(line) }
                continuation.resume(
                    returning: CLICommandResult(
                        terminationStatus: completedProcess.terminationStatus,
                        output: finished.output))
            }
            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

private struct ToolProvisioningError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

@MainActor
public final class ToolProvisioner: ObservableObject {
    public typealias RunCommand =
        @Sendable (
            CLICommandRequest, @escaping @Sendable (String) -> Void
        ) async throws -> CLICommandResult

    public static let shared = ToolProvisioner()

    @Published public private(set) var states: [String: CLIToolProvisionState] = [:]
    @Published public private(set) var logs: [String: [String]] = [:]

    private let runCommand: RunCommand
    private var tasks: [String: Task<Void, Never>] = [:]

    public init(
        runCommand: @escaping RunCommand = { request, onLine in
            try await CLICommandRunner.run(request, onLine: onLine)
        }
    ) {
        self.runCommand = runCommand
    }

    public func state(for tool: CLIToolSpec) -> CLIToolProvisionState {
        states[tool.id] ?? .idle
    }

    @discardableResult
    public func check(_ tool: CLIToolSpec) -> Task<Void, Never> {
        start(tool, installIfMissing: false)
    }

    @discardableResult
    public func provision(_ tool: CLIToolSpec) -> Task<Void, Never> {
        start(tool, installIfMissing: true)
    }

    public func provision(_ tools: [CLIToolSpec]) {
        for tool in tools { provision(tool) }
    }

    private func start(_ tool: CLIToolSpec, installIfMissing: Bool) -> Task<Void, Never> {
        if let task = tasks[tool.id] { return task }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.perform(tool, installIfMissing: installIfMissing)
            self.tasks[tool.id] = nil
        }
        tasks[tool.id] = task
        return task
    }

    private func perform(_ tool: CLIToolSpec, installIfMissing: Bool) async {
        states[tool.id] = .checking
        logs[tool.id] = []
        if let version = await detectedVersion(for: tool) {
            states[tool.id] = .present(version: version)
            return
        }
        guard installIfMissing else {
            states[tool.id] = .failed(
                message: tool.displayName + " is not installed",
                instruction: tool.installStrategy.instruction)
            return
        }
        states[tool.id] = .installing(logTail: [])
        append("Installing " + tool.displayName + "...", for: tool)
        do {
            try await install(tool)
            guard await detectedVersion(for: tool) != nil else {
                throw ToolProvisioningError(
                    message: "Installation finished, but " + tool.displayName
                        + " could not be verified")
            }
            states[tool.id] = .installed
            append(tool.displayName + " is ready.", for: tool)
            NotificationCenter.default.post(
                name: .cliToolProvisioned, object: nil, userInfo: ["toolID": tool.id])
        } catch {
            let message = error.localizedDescription
            append(message, for: tool)
            states[tool.id] = .failed(
                message: message, instruction: tool.installStrategy.instruction)
        }
    }

    private func detectedVersion(for tool: CLIToolSpec) async -> String? {
        let name: String
        let arguments: [String]
        switch tool.presenceStrategy {
        case let .executable(executableName, versionArguments):
            name = executableName
            arguments = [executableName] + versionArguments
        }
        let request = CLICommandRequest(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"), arguments: arguments,
            environment: CLIToolEnvironment.sanitized())
        guard let result = try? await run(request, for: tool), result.terminationStatus == 0 else {
            return nil
        }
        let version = result.output.components(separatedBy: .newlines).first {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }?.trimmingCharacters(in: .whitespacesAndNewlines)
        return version ?? name
    }

    private func install(_ tool: CLIToolSpec) async throws {
        switch tool.installStrategy {
        case let .standaloneBinary(url, destinationName, _):
            try await installStandaloneBinary(
                url: url, destinationName: destinationName, tool: tool)
        case let .packageManagers(homebrewArguments, npmPackage, _):
            try await installPackage(
                homebrewArguments: homebrewArguments, npmPackage: npmPackage, tool: tool)
        }
    }

    private func installStandaloneBinary(
        url: URL, destinationName: String, tool: CLIToolSpec
    ) async throws {
        let binDirectory = AppData.supportDir.appendingPathComponent("bin")
        try FileManager.default.createDirectory(
            at: binDirectory, withIntermediateDirectories: true)
        let destination = binDirectory.appendingPathComponent(destinationName)
        let temporary = binDirectory.appendingPathComponent(
            ".\(destinationName)-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        append("Downloading " + url.absoluteString, for: tool)
        try await requireSuccess(
            executable: "/usr/bin/curl",
            arguments: [
                "--fail", "--location", "--progress-bar", url.absoluteString, "--output",
                temporary.path,
            ],
            tool: tool)
        try await requireSuccess(
            executable: "/bin/chmod", arguments: ["+x", temporary.path], tool: tool)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
        append("Saved " + destination.path, for: tool)
    }

    private func installPackage(
        homebrewArguments: [String], npmPackage: String, tool: CLIToolSpec
    ) async throws {
        if await commandIsPresent("brew", tool: tool) {
            append("Running brew " + homebrewArguments.joined(separator: " "), for: tool)
            let result = try await run(
                request(executable: "/usr/bin/env", arguments: ["brew"] + homebrewArguments),
                for: tool)
            if result.terminationStatus == 0 { return }
            append("Homebrew install failed, trying npm.", for: tool)
        } else {
            append("Homebrew was not found, checking npm.", for: tool)
        }
        guard await commandIsPresent("npm", tool: tool) else {
            throw ToolProvisioningError(
                message: "Neither Homebrew nor npm is available for installing "
                    + tool.displayName + ".")
        }
        append("Running npm install -g " + npmPackage, for: tool)
        try await requireSuccess(
            executable: "/usr/bin/env", arguments: ["npm", "install", "-g", npmPackage],
            tool: tool)
    }

    private func commandIsPresent(_ name: String, tool: CLIToolSpec) async -> Bool {
        guard
            let result = try? await run(
                request(executable: "/usr/bin/env", arguments: [name, "--version"]),
                for: tool)
        else { return false }
        return result.terminationStatus == 0
    }

    private func requireSuccess(
        executable: String, arguments: [String], tool: CLIToolSpec
    ) async throws {
        let result = try await run(
            request(executable: executable, arguments: arguments), for: tool)
        guard result.terminationStatus == 0 else {
            throw ToolProvisioningError(
                message: "Command exited with status "
                    + String(result.terminationStatus) + ".")
        }
    }

    private func request(executable: String, arguments: [String]) -> CLICommandRequest {
        CLICommandRequest(
            executableURL: URL(fileURLWithPath: executable), arguments: arguments,
            environment: CLIToolEnvironment.sanitized())
    }

    private func run(
        _ request: CLICommandRequest, for tool: CLIToolSpec
    ) async throws -> CLICommandResult {
        try await runCommand(request) { [weak self] line in
            Task { @MainActor in self?.append(line, for: tool) }
        }
    }

    private func append(_ line: String, for tool: CLIToolSpec) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var toolLogs = logs[tool.id, default: []]
        toolLogs.append(trimmed)
        if toolLogs.count > 200 { toolLogs.removeFirst(toolLogs.count - 200) }
        logs[tool.id] = toolLogs
        if case .installing = states[tool.id] {
            states[tool.id] = .installing(logTail: Array(toolLogs.suffix(12)))
        }
    }
}
