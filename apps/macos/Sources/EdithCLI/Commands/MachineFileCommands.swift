import ArgumentParser
import EdithKit
import Foundation

struct MachinesFilesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "files",
        abstract: "Browse and transfer files on a machine.",
        subcommands: [
            MachineFilesListCommand.self, MachineFilesGetCommand.self,
            MachineFilesPutCommand.self, MachinesFilesCopyCommand.self,
            MachinesFilesMoveCommand.self, MachinesFilesRenameCommand.self,
            MachinesFilesMakeDirectoryCommand.self, MachinesFilesRemoveCommand.self,
        ],
        defaultSubcommand: MachineFilesListCommand.self)
}

struct MachineFilesListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls", abstract: "List a remote directory.", aliases: ["list"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(name: [.long, .short], help: "Include dotfiles.")
    var all = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "Remote directory.")
    var path: String = "."

    func run() async throws {
        try await execute {
            let runner = try await MachineResolver.runner(machine)
            let resolved = path == "." ? try await homeDirectory(runner) : path
            let result = try await runner.run(
                FileListing.command(path: resolved, showHidden: true), timeout: 45)
            var entries = FileListing.parse(output: result.stdoutText, parent: resolved)
            if entries.isEmpty, !result.succeeded {
                throw CLIFailure(
                    "could not read \(resolved) on \(runner.machine.name)",
                    hint: result.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if !all { entries = entries.filter { !$0.isHidden } }
            guard !json else {
                CLIOut.json(
                    .object([
                        "path": .string(resolved),
                        "entries": .array(entries.map(MachineReports.file)),
                    ]))
                return
            }
            let rows = entries.map { entry in
                [
                    entry.kind == .directory ? "d" : (entry.kind == .symlink ? "l" : "-"),
                    entry.mode,
                    entry.kind == .directory ? "" : ByteFormatter.string(entry.sizeBytes),
                    entry.name,
                ]
            }
            CLIOut.out(TextTable.render(headers: ["T", "MODE", "SIZE", "NAME"], rows: rows))
        }
    }

    private func homeDirectory(_ runner: RemoteRunner) async throws -> String {
        let output = try await runner.text("printf %s \"$HOME\"", timeout: 15)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "/" : trimmed
    }
}

struct MachineFilesGetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get", abstract: "Download a file from a machine.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "Remote file path.")
    var remote: String

    @Argument(help: "Local destination. Defaults to the file name in the working directory.")
    var local: String?

    func run() async throws {
        try await execute {
            let runner = try await MachineResolver.runner(machine)
            let destination = URL(
                fileURLWithPath: (local ?? (remote as NSString).lastPathComponent as String)
                    .expandingTilde())
            do {
                try await runner.ssh.download(remotePath: remote, to: destination)
            } catch {
                throw CLIFailure("download failed: \(error.localizedDescription)")
            }
            let size =
                (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size])
                as? Int ?? 0
            guard !json else {
                CLIOut.json(
                    .object([
                        "remote": .string(remote),
                        "local": .string(destination.path),
                        "sizeBytes": .int(size),
                    ]))
                return
            }
            CLIOut.out("\(destination.path)  \(ByteFormatter.string(Int64(size)))")
        }
    }
}

struct MachineFilesPutCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "put", abstract: "Upload a file to a machine.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "Local file path.")
    var local: String

    @Argument(help: "Remote destination path.")
    var remote: String

    func run() async throws {
        try await execute {
            let source = URL(fileURLWithPath: local.expandingTilde())
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw CLIFailure.notFound("no file at \(source.path)")
            }
            let runner = try await MachineResolver.runner(machine)
            do {
                try await runner.ssh.upload(localURL: source, toRemotePath: remote)
            } catch {
                throw CLIFailure("upload failed: \(error.localizedDescription)")
            }
            let size =
                (try? FileManager.default.attributesOfItem(atPath: source.path)[.size]) as? Int
                ?? 0
            guard !json else {
                CLIOut.json(
                    .object([
                        "local": .string(source.path),
                        "remote": .string(remote),
                        "sizeBytes": .int(size),
                    ]))
                return
            }
            CLIOut.out("\(remote)  \(ByteFormatter.string(Int64(size)))")
        }
    }
}

extension String {
    func expandingTilde() -> String {
        (self as NSString).expandingTildeInPath
    }
}
