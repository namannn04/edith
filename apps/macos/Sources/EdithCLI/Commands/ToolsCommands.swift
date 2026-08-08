import ArgumentParser
import EdithKit
import Foundation

struct ToolsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        abstract: "The command line tools Edith's extensions rely on.",
        discussion: """
            These are the tools an extension needs before it can do its job: yt-dlp for
            downloads, and the agent CLIs whose usage the dashboard reads. `ls` checks what
            is on PATH; `install` fetches the one you name the same way the extension sheet
            does.
            """,
        subcommands: [ToolsListCommand.self, ToolsInstallCommand.self],
        defaultSubcommand: ToolsListCommand.self)
}

enum ToolsBridge {
    static let all: [CLIToolSpec] = ToolProvisioning.all

    static func resolve(_ id: String) throws -> CLIToolSpec {
        let needle = id.lowercased()
        if let exact = all.first(where: { $0.id.lowercased() == needle }) { return exact }
        if let byName = all.first(where: { $0.displayName.lowercased() == needle }) {
            return byName
        }
        throw CLIFailure.notFound(
            "no tool called \(id)",
            hint: "tools: " + all.map(\.id).joined(separator: ", "))
    }

    static func found(_ spec: CLIToolSpec) -> URL? {
        guard case let .executable(name, _) = spec.presenceStrategy else { return nil }
        return CLIToolEnvironment.executable(named: name)
    }

    static func version(_ spec: CLIToolSpec) -> String? {
        guard case let .executable(_, arguments) = spec.presenceStrategy,
            let executable = found(spec)
        else { return nil }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = CLIToolEnvironment.sanitized()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text.split(separator: "\n").first.map(String.init)
    }
}

struct ToolsListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls", abstract: "List the tools and whether they are installed.",
        aliases: ["list"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    func run() async throws {
        try await execute {
            let rows = ToolsBridge.all.map { spec -> (CLIToolSpec, URL?, String?) in
                let path = ToolsBridge.found(spec)
                return (spec, path, path == nil ? nil : ToolsBridge.version(spec))
            }
            guard !json else {
                CLIOut.json(
                    .array(
                        rows.map { spec, path, version in
                            .object([
                                "id": .string(spec.id),
                                "name": .string(spec.displayName),
                                "why": .string(spec.why),
                                "installed": .bool(path != nil),
                                "path": .optional(path?.path),
                                "version": .optional(version),
                            ])
                        }))
                return
            }
            CLIOut.out(
                TextTable.render(
                    headers: ["ID", "STATE", "VERSION", "WHY"],
                    rows: rows.map { spec, path, version in
                        [
                            spec.id, path == nil ? "missing" : "installed", version ?? "",
                            spec.why,
                        ]
                    }))
        }
    }
}

struct ToolsInstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install", abstract: "Install one of the tools.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "The tool id: yt-dlp, claude or codex.")
    var tool: String

    func run() async throws {
        try await execute {
            let spec = try ToolsBridge.resolve(tool)
            if let existing = ToolsBridge.found(spec) {
                guard !json else {
                    CLIOut.json(
                        .object([
                            "id": .string(spec.id), "installed": .bool(true),
                            "path": .string(existing.path), "changed": .bool(false),
                        ]))
                    return
                }
                CLIOut.note("\(spec.id) is already at \(existing.path)")
                return
            }
            try AppBridge.requireHelper("installing \(spec.id)")
            AppBridge.post(
                IPC.Name.requestToolInstall, userInfo: ["toolID": spec.id])
            guard !json else {
                CLIOut.json(
                    .object([
                        "id": .string(spec.id), "requested": .bool(true),
                        "installed": .bool(false),
                    ]))
                return
            }
            CLIOut.out("asked Edith to install \(spec.id)")
            CLIOut.note("run `ed tools ls` to see when it lands")
        }
    }
}
