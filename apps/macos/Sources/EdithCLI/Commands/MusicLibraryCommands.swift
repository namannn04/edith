import ArgumentParser
import EdithKit
import Foundation

enum LibraryBridge {
    static func requireFolder() throws {
        guard
            let path = CLIEnvironment.sharedDefaults.string(forKey: Repo.musicFolderPathKey),
            !path.isEmpty
        else {
            throw CLIFailure.unavailable(
                "no music folder is set",
                hint: "choose one in Edith under Music, or run `ed config set musicFolderPath "
                    + "~/Music`")
        }
    }

    static func track(_ query: String) throws -> Track {
        try requireFolder()
        if let exact = try? MusicLibrary.track(at: query) { return exact }
        let needle = query.lowercased()
        let all = TrackMeta.scanMusicFolder()
        let matches = all.filter {
            $0.relativePath.lowercased().contains(needle)
                || $0.title.lowercased().contains(needle)
        }
        if matches.count == 1, let only = matches.first { return only }
        if matches.count > 1 {
            throw CLIFailure.notFound(
                "\(query) matches \(matches.count) tracks",
                hint: matches.prefix(5).map(\.relativePath).joined(separator: ", "))
        }
        throw CLIFailure.notFound(
            "no track matching \(query)", hint: "run `ed music ls` to see what is there")
    }

    static func folder(_ path: String) throws -> MusicFolder {
        try requireFolder()
        do {
            return try MusicLibrary.folder(at: path)
        } catch {
            throw CLIFailure.notFound(
                "no folder called \(path)", hint: "run `ed music ls --folders` to see them")
        }
    }

    static func fail(_ error: Error) -> CLIFailure {
        guard let library = error as? MusicLibraryError else {
            return CLIFailure(error.localizedDescription)
        }
        switch library {
        case .emptyName: return CLIFailure("a name cannot be blank")
        case let .alreadyThere(path): return CLIFailure("\(path) is already there")
        case let .noSuchTrack(path): return CLIFailure.notFound("no track at \(path)")
        case let .noSuchFolder(path): return CLIFailure.notFound("no folder at \(path)")
        case let .failed(message): return CLIFailure(message)
        }
    }

    static func announce() {
        AppBridge.post(IPC.Name.musicFolderChanged)
    }

    static func json(_ track: Track) -> JSONValue {
        .object([
            "path": .string(track.relativePath),
            "title": .string(track.title),
            "file": .string(track.url.lastPathComponent),
        ])
    }
}

struct MusicListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls",
        abstract: "List the music library, a folder at a time.",
        aliases: ["list"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(help: "Only folders.")
    var folders = false

    @Flag(help: "Every track underneath, not just this folder.")
    var recursive = false

    @Option(help: "Only entries whose path or title contains this text.")
    var search: String?

    @Argument(help: "Folder to list, relative to the library root.")
    var folder: String = ""

    func run() async throws {
        try await execute {
            let target = try LibraryBridge.folder(folder)
            let tracks =
                recursive
                ? TrackMeta.tracks(under: target.relativePath)
                : TrackMeta.entries(in: target.relativePath).tracks
            let children = TrackMeta.subfolders(in: target.relativePath)
            let needle = (search ?? "").lowercased()
            let shown =
                needle.isEmpty
                ? tracks
                : tracks.filter {
                    $0.relativePath.lowercased().contains(needle)
                        || $0.title.lowercased().contains(needle)
                }
            guard !json else {
                CLIOut.json(
                    .object([
                        "folder": .string(target.relativePath),
                        "folders": .array(
                            children.map {
                                .object([
                                    "path": .string($0.relativePath),
                                    "name": .string($0.name),
                                    "tracks": .int(
                                        TrackMeta.trackCount(under: $0.relativePath)),
                                ])
                            }),
                        "tracks": .array(folders ? [] : shown.map(LibraryBridge.json)),
                    ]))
                return
            }
            if !children.isEmpty {
                CLIOut.out(
                    TextTable.render(
                        headers: ["FOLDER", "TRACKS"],
                        rows: children.map {
                            [$0.relativePath, String(TrackMeta.trackCount(under: $0.relativePath))]
                        }))
            }
            guard !folders else { return }
            guard !shown.isEmpty else {
                if children.isEmpty { CLIOut.note("nothing here") }
                return
            }
            if !children.isEmpty { CLIOut.out("") }
            CLIOut.out(
                TextTable.render(
                    headers: ["TITLE", "PATH"],
                    rows: shown.map { [$0.title, $0.relativePath] }))
        }
    }
}

struct MusicNewFolderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mkdir", abstract: "Make a folder in the library.", aliases: ["newfolder"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(help: "Folder to make it inside, relative to the library root.")
    var under: String = ""

    @Argument(help: "What to call it.")
    var name: String

    func run() async throws {
        try await execute {
            _ = try LibraryBridge.folder(under)
            let made: MusicFolder
            do {
                made = try MusicLibrary.createFolder(named: name, under: under)
            } catch {
                throw LibraryBridge.fail(error)
            }
            LibraryBridge.announce()
            guard !json else {
                CLIOut.json(
                    .object([
                        "path": .string(made.relativePath), "name": .string(made.name),
                    ]))
                return
            }
            CLIOut.out("made \(made.relativePath)")
        }
    }
}

struct MusicMoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mv", abstract: "Move a track into a folder.", aliases: ["move"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Track path, or enough of its name to be unambiguous.")
    var track: String

    @Argument(help: "Destination folder, relative to the library root.")
    var folder: String

    func run() async throws {
        try await execute {
            let found = try LibraryBridge.track(track)
            _ = try LibraryBridge.folder(folder)
            let move: MusicLibrary.Move
            do {
                move = try MusicLibrary.move(found, toFolder: folder)
            } catch {
                throw LibraryBridge.fail(error)
            }
            AppBridge.post(
                IPC.Name.musicCommand,
                userInfo: ["action": "renamed", "from": move.from, "to": move.to])
            LibraryBridge.announce()
            guard !json else {
                CLIOut.json(.object(["from": .string(move.from), "to": .string(move.to)]))
                return
            }
            CLIOut.out("moved to \(move.to)")
        }
    }
}

struct MusicRenameCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rename", abstract: "Rename a track or a folder.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(help: "Rename a folder rather than a track.")
    var folder = false

    @Argument(help: "Track path or folder path.")
    var target: String

    @Argument(help: "The new name, without the extension.")
    var name: String

    func run() async throws {
        try await execute {
            let move: MusicLibrary.Move
            do {
                move =
                    folder
                    ? try MusicLibrary.renameFolder(LibraryBridge.folder(target), to: name)
                    : try MusicLibrary.rename(LibraryBridge.track(target), to: name)
            } catch let failure as CLIFailure {
                throw failure
            } catch {
                throw LibraryBridge.fail(error)
            }
            AppBridge.post(
                IPC.Name.musicCommand,
                userInfo: ["action": "renamed", "from": move.from, "to": move.to])
            LibraryBridge.announce()
            guard !json else {
                CLIOut.json(.object(["from": .string(move.from), "to": .string(move.to)]))
                return
            }
            CLIOut.out("renamed to \(move.to)")
        }
    }
}

struct MusicRemoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm",
        abstract: "Move a track or folder to the Trash.",
        discussion: """
            Nothing is deleted outright: this puts the file in the Trash, the same as the
            UI does, so it can be put back from Finder.
            """)

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(help: "Remove a folder and everything in it.")
    var folder = false

    @Flag(help: "Actually do it. Without this nothing is moved.")
    var yes = false

    @Argument(help: "Track path or folder path.")
    var target: String

    func run() async throws {
        try await execute {
            let path: String
            let count: Int
            if folder {
                let found = try LibraryBridge.folder(target)
                path = found.relativePath
                count = TrackMeta.trackCount(under: found.relativePath)
                guard yes else { return preview(path, count: count) }
                do { try MusicLibrary.trashFolder(found) } catch { throw LibraryBridge.fail(error) }
            } else {
                let found = try LibraryBridge.track(target)
                path = found.relativePath
                count = 1
                guard yes else { return preview(path, count: count) }
                do { try MusicLibrary.trash(found) } catch { throw LibraryBridge.fail(error) }
            }
            LibraryBridge.announce()
            guard !json else {
                CLIOut.json(
                    .object([
                        "path": .string(path), "tracks": .int(count), "trashed": .bool(true),
                    ]))
                return
            }
            CLIOut.out("moved \(path) to the Trash")
        }
    }

    private func preview(_ path: String, count: Int) {
        guard !json else {
            CLIOut.json(
                .object(["path": .string(path), "tracks": .int(count), "trashed": .bool(false)]))
            return
        }
        CLIOut.out("would move \(path) to the Trash (\(count) track(s))")
        CLIOut.note("nothing was moved; pass --yes to go ahead")
    }
}
