import ArgumentParser
import EdithKit
import Foundation

enum FileOps {
    static func apply(
        _ command: String, machine name: String, describing what: String, json: Bool,
        fields: [String: JSONValue]
    ) async throws {
        let runner = try await MachineResolver.runner(name)
        let result = try await runner.run(command, timeout: 300)
        let detail = result.combinedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.succeeded else {
            throw CLIFailure(
                "\(what) failed on \(runner.machine.name)" + (detail.isEmpty ? "" : ": \(detail)"))
        }
        guard !json else {
            var payload = fields
            payload["machine"] = .string(runner.machine.name)
            payload["done"] = .bool(true)
            CLIOut.json(.object(payload))
            return
        }
        CLIOut.out(what)
    }
}

struct MachinesFilesCopyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cp", abstract: "Copy files into a directory on the machine.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "Paths to copy, then the destination directory last.")
    var paths: [String]

    func run() async throws {
        try await execute {
            guard paths.count >= 2 else {
                throw CLIFailure("give at least one source and a destination directory")
            }
            let destination = paths[paths.count - 1]
            let sources = Array(paths.dropLast())
            try await FileOps.apply(
                FileOperations.copyCommand(paths: sources, toDirectory: destination),
                machine: machine,
                describing: "copied \(sources.count) into \(destination)", json: json,
                fields: ["copied": .strings(sources), "into": .string(destination)])
        }
    }
}

struct MachinesFilesMoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mv", abstract: "Move files into a directory on the machine.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "Paths to move, then the destination directory last.")
    var paths: [String]

    func run() async throws {
        try await execute {
            guard paths.count >= 2 else {
                throw CLIFailure("give at least one source and a destination directory")
            }
            let destination = paths[paths.count - 1]
            let sources = Array(paths.dropLast())
            try await FileOps.apply(
                FileOperations.moveCommand(paths: sources, toDirectory: destination),
                machine: machine,
                describing: "moved \(sources.count) into \(destination)", json: json,
                fields: ["moved": .strings(sources), "into": .string(destination)])
        }
    }
}

struct MachinesFilesRenameCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rename", abstract: "Rename one file on the machine.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "The path to rename.")
    var path: String

    @Argument(help: "The new name, without a directory.")
    var name: String

    func run() async throws {
        try await execute {
            guard !name.contains("/") else {
                throw CLIFailure(
                    "a new name cannot contain a slash",
                    hint: "use `ed machines files mv` to move it somewhere else")
            }
            let destination = (path as NSString).deletingLastPathComponent
            let target =
                destination.isEmpty ? name : (destination as NSString).appendingPathComponent(name)
            try await FileOps.apply(
                FileOperations.renameCommand(path: path, to: target), machine: machine,
                describing: "renamed to \(target)", json: json,
                fields: ["path": .string(path), "to": .string(target)])
        }
    }
}

struct MachinesFilesMakeDirectoryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mkdir", abstract: "Make a directory on the machine.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "The directory to make.")
    var path: String

    func run() async throws {
        try await execute {
            try await FileOps.apply(
                FileOperations.makeDirectoryCommand(path: path), machine: machine,
                describing: "made \(path)", json: json, fields: ["path": .string(path)])
        }
    }
}

struct MachinesFilesRemoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm",
        abstract: "Move files to the machine's trash, or delete them outright.",
        discussion: """
            Without `--delete` this moves the files to the machine's own trash, the same as
            the Finder window does, so they can be put back. `--delete` removes them for
            good and needs `--yes`.
            """)

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(help: "Delete outright rather than moving to the trash.")
    var delete = false

    @Flag(help: "Actually do it. Required with --delete.")
    var yes = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "Paths to remove.")
    var paths: [String]

    func run() async throws {
        try await execute {
            guard !paths.isEmpty else { throw CLIFailure("name at least one path") }
            guard !delete || yes else {
                guard !json else {
                    CLIOut.json(
                        .object(["paths": .strings(paths), "deleted": .bool(false)]))
                    return
                }
                CLIOut.out("would delete \(paths.count) path(s) for good")
                CLIOut.note("nothing was deleted; pass --yes to go ahead")
                return
            }
            let command =
                delete
                ? FileOperations.deleteCommand(paths: paths)
                : FileOperations.trashCommand(paths: paths)
            try await FileOps.apply(
                command, machine: machine,
                describing: delete
                    ? "deleted \(paths.count) path(s)" : "trashed \(paths.count) path(s)",
                json: json,
                fields: ["paths": .strings(paths), "deleted": .bool(delete)])
        }
    }
}
