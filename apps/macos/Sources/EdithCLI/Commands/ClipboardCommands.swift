import AppKit
import ArgumentParser
import EdithKit
import Foundation

struct ClipboardCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clipboard",
        abstract: "The clipboard history Edith keeps.",
        discussion: """
            The history is a file on disk, so these read commands work whether or not
            the app is running. Entries are numbered from 1, newest first, and that
            number is what `get`, `copy` and `rm` take.
            """,
        subcommands: [
            ClipboardListCommand.self, ClipboardGetCommand.self, ClipboardCopyCommand.self,
            ClipboardRemoveCommand.self, ClipboardClearCommand.self,
        ],
        defaultSubcommand: ClipboardListCommand.self)
}

enum ClipboardBridge {
    static func entries() -> [ClipboardEntry] {
        ClipboardRepository.loadEntries().sorted { $0.lastCopiedAt > $1.lastCopiedAt }
    }

    static func entry(at index: Int) throws -> (entry: ClipboardEntry, all: [ClipboardEntry]) {
        let all = entries()
        guard !all.isEmpty else {
            throw CLIFailure.unavailable(
                "the clipboard history is empty",
                hint: "turn the Clipboard extension on with `ed extensions enable clipboard`")
        }
        guard index >= 1, index <= all.count else {
            throw CLIFailure.notFound(
                "there is no clipboard entry \(index)",
                hint: "the history holds \(all.count) entries, numbered from 1")
        }
        return (all[index - 1], all)
    }

    static func json(_ entry: ClipboardEntry, index: Int) -> JSONValue {
        .object([
            "index": .int(index),
            "id": .string(entry.id),
            "kind": .string(entry.ext),
            "isText": .bool(entry.isTextual),
            "preview": .optional(entry.preview),
            "sourceApp": .optional(entry.sourceApp),
            "sizeBytes": .int(entry.size),
            "pinned": .bool(entry.pinned),
            "copiedAt": .date(entry.lastCopiedAt),
        ])
    }

    static func text(_ entry: ClipboardEntry) throws -> String {
        guard let data = ClipboardRepository.blobData(for: entry) else {
            throw CLIFailure.notFound(
                "the stored copy of that entry is gone",
                hint: "run `ed clipboard ls` to see what is still there")
        }
        guard let text = ClipboardRepository.plainText(for: entry, data: data) else {
            throw CLIFailure(
                "entry \(entry.ext) is not text",
                hint: "use `ed clipboard copy` to put it back on the pasteboard instead")
        }
        return text
    }
}

struct ClipboardListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls", abstract: "List the clipboard history, newest first.",
        aliases: ["list"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(help: "Only pinned entries.")
    var pinned = false

    @Option(help: "Show at most this many entries.")
    var limit: Int = 25

    func run() async throws {
        try await execute {
            let limit = try ArgumentChecks.positive(self.limit, "--limit")
            var entries = ClipboardBridge.entries()
            if pinned { entries = entries.filter(\.pinned) }
            let shown = Array(entries.prefix(limit))
            guard !json else {
                CLIOut.json(
                    .array(
                        shown.enumerated().map { ClipboardBridge.json($1, index: $0 + 1) }))
                return
            }
            let rows = shown.enumerated().map { offset, entry in
                [
                    String(offset + 1), entry.ext, entry.pinned ? "pinned" : "",
                    entry.sourceApp ?? "", entry.preview ?? "",
                ]
            }
            CLIOut.out(
                TextTable.render(headers: ["#", "KIND", "", "FROM", "PREVIEW"], rows: rows))
        }
    }
}

struct ClipboardGetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get", abstract: "Print one entry as text.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "The entry number, counting from 1.")
    var index: Int

    func run() async throws {
        try await execute {
            let found = try ClipboardBridge.entry(at: index)
            let text = try ClipboardBridge.text(found.entry)
            guard !json else {
                guard case var .object(fields) = ClipboardBridge.json(found.entry, index: index)
                else { return }
                fields["text"] = .string(text)
                CLIOut.json(.object(fields))
                return
            }
            CLIOut.out(text)
        }
    }
}

struct ClipboardCopyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "copy", abstract: "Put one entry back on the pasteboard.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(help: "Copy as plain text even when the entry is styled.")
    var plain = false

    @Argument(help: "The entry number, counting from 1.")
    var index: Int

    func run() async throws {
        try await execute {
            let found = try ClipboardBridge.entry(at: index)
            guard
                ClipboardRepository.copyToPasteboard(found.entry, asPlainText: plain)
            else {
                throw CLIFailure.notFound("the stored copy of that entry is gone")
            }
            guard !json else {
                CLIOut.json(ClipboardBridge.json(found.entry, index: index))
                return
            }
            CLIOut.out("copied entry \(index)")
        }
    }
}

struct ClipboardRemoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm", abstract: "Forget one entry.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "The entry number, counting from 1.")
    var index: Int

    func run() async throws {
        try await execute {
            let found = try ClipboardBridge.entry(at: index)
            let kept = found.all.filter { $0.id != found.entry.id }
            try ClipboardRepository.saveEntries(kept)
            ClipboardRepository.pruneOrphanBlobs(keeping: kept)
            AppBridge.post(IPC.Name.clipboardChanged)
            guard !json else {
                CLIOut.json(.object(["removed": .int(index), "remaining": .int(kept.count)]))
                return
            }
            CLIOut.out("removed entry \(index), \(kept.count) left")
        }
    }
}

struct ClipboardClearCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear", abstract: "Forget the whole history.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(help: "Keep pinned entries.")
    var keepPinned = false

    func run() async throws {
        try await execute {
            let all = ClipboardBridge.entries()
            let kept = keepPinned ? all.filter(\.pinned) : []
            try ClipboardRepository.saveEntries(kept)
            ClipboardRepository.pruneOrphanBlobs(keeping: kept)
            AppBridge.post(IPC.Name.clipboardChanged)
            guard !json else {
                CLIOut.json(
                    .object([
                        "removed": .int(all.count - kept.count), "remaining": .int(kept.count),
                    ]))
                return
            }
            CLIOut.out("cleared \(all.count - kept.count) entries")
        }
    }
}

struct ColorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "color",
        abstract: "The colours picked with Edith's colour picker.",
        subcommands: [ColorListCommand.self, ColorClearCommand.self],
        defaultSubcommand: ColorListCommand.self,
        aliases: ["colour"])
}

struct ColorListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls", abstract: "List picked colours, newest first.", aliases: ["list"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(help: "Print each colour in one format: hex, rgb, hsl, swiftUI or nsColor.")
    var format: String?

    @Option(help: "Show at most this many colours.")
    var limit: Int = 25

    func run() async throws {
        try await execute {
            let limit = try ArgumentChecks.positive(self.limit, "--limit")
            var chosen: ColorCopyFormat?
            if let format {
                guard let value = ColorCopyFormat(rawValue: format) else {
                    throw CLIFailure.notFound(
                        "no colour format named \(format)",
                        hint: "formats: "
                            + ColorCopyFormat.allCases.map(\.rawValue).joined(separator: ", "))
                }
                chosen = value
            }
            let swatches = Array(
                ColorHistoryStore.load(from: CLIEnvironment.sharedDefaults).prefix(limit))
            guard !json else {
                CLIOut.json(
                    .array(
                        swatches.map { swatch in
                            .object([
                                "hex": .string(swatch.string(for: .hex)),
                                "rgb": .string(swatch.string(for: .rgb)),
                                "hsl": .string(swatch.string(for: .hsl)),
                                "profile": .string(swatch.profile.rawValue),
                                "pickedAt": .date(swatch.pickedAt),
                            ])
                        }))
                return
            }
            if let chosen {
                for swatch in swatches { CLIOut.out(swatch.string(for: chosen)) }
                return
            }
            guard !swatches.isEmpty else {
                CLIOut.note("no colours picked yet")
                return
            }
            let rows = swatches.map { swatch in
                [
                    swatch.string(for: .hex), swatch.string(for: .rgb),
                    swatch.profile.displayName,
                    JSONSerializer.iso.string(from: swatch.pickedAt),
                ]
            }
            CLIOut.out(
                TextTable.render(headers: ["HEX", "RGB", "PROFILE", "PICKED"], rows: rows))
        }
    }
}

struct ColorClearCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear", abstract: "Forget every picked colour.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    func run() async throws {
        try await execute {
            let count = ColorHistoryStore.load(from: CLIEnvironment.sharedDefaults).count
            ColorHistoryStore.clear(in: CLIEnvironment.sharedDefaults)
            ConfigStore.announceChange()
            guard !json else {
                CLIOut.json(.object(["removed": .int(count)]))
                return
            }
            CLIOut.out("cleared \(count) colours")
        }
    }
}
