import Foundation

public struct MachineMount: Equatable, Sendable {
    public var target: String
    public var remotePath: String
    public var mountPoint: String
    public var isReadOnly: Bool

    public init(
        target: String, remotePath: String, mountPoint: String, isReadOnly: Bool = false
    ) {
        self.target = target
        self.remotePath = remotePath
        self.mountPoint = mountPoint
        self.isReadOnly = isReadOnly
    }

    public var source: String { "\(target):\(remotePath)" }
}

public enum MachineMountError: LocalizedError, Equatable {
    case toolMissing
    case alreadyMounted(String)
    case notMounted(String)
    case mountPointBusy(String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .toolMissing:
            return "sshfs is not installed on this Mac."
        case let .alreadyMounted(path):
            return "That machine is already mounted at \(path)."
        case let .notMounted(name):
            return "\(name) is not mounted."
        case let .mountPointBusy(path):
            return "\(path) already has something in it."
        case let .failed(message):
            return message.isEmpty ? "The mount failed." : message
        }
    }

    public var hint: String? {
        switch self {
        case .toolMissing:
            return "install macFUSE and sshfs: brew install --cask macfuse"
                + " && brew install gromgit/fuse/sshfs-mac"
        case .mountPointBusy:
            return "pick another folder with --at, or empty that one"
        default:
            return nil
        }
    }
}

public enum MachineMounts {
    nonisolated(unsafe) public static var root: URL =
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Edith")

    public static let toolName = "sshfs"

    public static func folderName(for machine: Machine) -> String {
        let cleaned = machine.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? machine.id.uuidString : cleaned
    }

    public static func mountPoint(for machine: Machine) -> URL {
        root.appendingPathComponent(folderName(for: machine))
    }

    public static func executable() -> URL? {
        CLIToolEnvironment.executable(named: toolName)
    }

    public static var isAvailable: Bool { executable() != nil }

    public static func parse(_ output: String) -> [MachineMount] {
        output.split(separator: "\n").compactMap { line in
            let text = String(line)
            guard let separator = text.range(of: " on ") else { return nil }
            let source = String(text[text.startIndex..<separator.lowerBound])
            let rest = String(text[separator.upperBound...])
            guard let optionsStart = rest.range(of: " (", options: .backwards) else { return nil }
            let options = String(rest[optionsStart.upperBound...]).replacingOccurrences(
                of: ")", with: "")
            let kinds = options.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard kinds.contains(where: { $0.contains("fuse") }) else { return nil }
            guard let colon = source.firstIndex(of: ":") else { return nil }
            return MachineMount(
                target: String(source[source.startIndex..<colon]),
                remotePath: String(source[source.index(after: colon)...]),
                mountPoint: String(rest[rest.startIndex..<optionsStart.lowerBound]),
                isReadOnly: kinds.contains("read-only"))
        }
    }

    public static func mount(for machine: Machine, in mounts: [MachineMount]) -> MachineMount? {
        mounts.first { $0.target == machine.sshTarget }
    }

    public static func list() async -> [MachineMount] {
        let result = await run(URL(fileURLWithPath: "/sbin/mount"), [])
        return parse(result.output)
    }

    public static func current(for machine: Machine) async -> MachineMount? {
        mount(for: machine, in: await list())
    }

    public static func mountArguments(
        machine: Machine, remotePath: String, mountPoint: String, readOnly: Bool,
        uid: uid_t = getuid(), gid: gid_t = getgid()
    ) -> [String] {
        var options = [
            "volname=\(folderName(for: machine))",
            "ControlPath=\(MachinePaths.socketFile(for: machine.id).path)",
            "ControlMaster=no",
            "BatchMode=yes",
            "reconnect",
            "ServerAliveInterval=15",
            "ServerAliveCountMax=3",
            "defer_permissions",
            "noappledouble",
            "noapplexattr",
            "idmap=user",
            "uid=\(uid)",
            "gid=\(gid)",
        ]
        if readOnly { options.append("ro") }
        var arguments = ["\(machine.sshTarget):\(remotePath)", mountPoint]
        if case .manual = machine.source {
            arguments += ["-p", String(machine.port)]
            if case let .keyFile(path, _) = machine.auth {
                options += [
                    "IdentityFile=\(SSHConfigFile.expandTilde(path))",
                    "IdentitiesOnly=yes",
                ]
            }
        }
        for option in options { arguments += ["-o", option] }
        return arguments
    }

    @discardableResult
    public static func mount(
        machine: Machine, remotePath: String, at mountPoint: URL? = nil, readOnly: Bool = false
    ) async throws -> MachineMount {
        guard let tool = executable() else { throw MachineMountError.toolMissing }
        if let existing = await current(for: machine) {
            throw MachineMountError.alreadyMounted(existing.mountPoint)
        }
        let destination = mountPoint ?? Self.mountPoint(for: machine)
        try prepare(destination)
        let arguments = mountArguments(
            machine: machine, remotePath: remotePath, mountPoint: destination.path,
            readOnly: readOnly)
        let result = await run(tool, arguments)
        guard let landed = await current(for: machine) else {
            try? FileManager.default.removeItem(at: destination)
            throw MachineMountError.failed(explain(result))
        }
        return landed
    }

    @discardableResult
    public static func unmount(machine: Machine) async throws -> MachineMount {
        guard let existing = await current(for: machine) else {
            throw MachineMountError.notMounted(machine.name)
        }
        var result = await run(
            URL(fileURLWithPath: "/sbin/umount"), [existing.mountPoint])
        if result.status != 0 {
            result = await run(
                URL(fileURLWithPath: "/usr/sbin/diskutil"),
                ["unmount", "force", existing.mountPoint])
        }
        guard await current(for: machine) == nil else {
            throw MachineMountError.failed(explain(result))
        }
        discardEmptyFolder(at: existing.mountPoint)
        return existing
    }

    static func prepare(_ mountPoint: URL) throws {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: mountPoint.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue,
                (try? fm.contentsOfDirectory(atPath: mountPoint.path))?.isEmpty != false
            else { throw MachineMountError.mountPointBusy(mountPoint.path) }
            return
        }
        do {
            try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        } catch {
            throw MachineMountError.failed(error.localizedDescription)
        }
    }

    private static func discardEmptyFolder(at path: String) {
        let fm = FileManager.default
        guard path.hasPrefix(root.path + "/"),
            (try? fm.contentsOfDirectory(atPath: path))?.isEmpty == true
        else { return }
        try? fm.removeItem(atPath: path)
    }

    private static func explain(_ result: (status: Int32, output: String)) -> String {
        let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else {
            return trimmed.split(separator: "\n").last.map(String.init) ?? trimmed
        }
        return "the command exited with status \(result.status)"
    }

    private static func run(_ executable: URL, _ arguments: [String]) async -> (
        status: Int32, output: String
    ) {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.environment = CLIToolEnvironment.sanitized()
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.standardInput = FileHandle.nullDevice
            guard (try? process.run()) != nil else {
                return (Int32(-1), "\(executable.lastPathComponent) could not be started")
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }.value
    }
}
