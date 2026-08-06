import ArgumentParser
import EdithKit
import Foundation

struct MusicCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "music",
        abstract: "What is playing, and playback control.",
        discussion: """
            Playback lives in the Edith menu bar app, so these commands talk to it over
            the app's own notification bus. They exit 4 when the app is not running or
            the Music extension is off.
            """,
        subcommands: [
            MusicStatusCommand.self, MusicPlayCommand.self, MusicPauseCommand.self,
            MusicToggleCommand.self, MusicNextCommand.self, MusicPreviousCommand.self,
            MusicVolumeCommand.self,
        ],
        defaultSubcommand: MusicStatusCommand.self)
}

enum MusicBridge {
    static func requireExtension() throws {
        try AppBridge.requireHelper("music control")
        guard SharedDefaults.store.object(forKey: "tabMusicEnabled") as? Bool ?? false else {
            throw CLIFailure.unavailable(
                "the Music extension is off",
                hint: "run `ed extensions enable music`")
        }
    }

    static func state(timeout: TimeInterval = 3) async throws -> JSONValue {
        try requireExtension()
        guard
            let payload = await AppBridge.awaitReply(
                IPC.Name.musicState, timeout: timeout,
                trigger: {
                    AppBridge.post(IPC.Name.requestMusicState)
                })
        else {
            throw CLIFailure.unavailable("the app did not report playback state in time")
        }
        return json(payload)
    }

    static func json(_ payload: [AnyHashable: Any]) -> JSONValue {
        let track = payload["track"] as? String ?? ""
        return .object([
            "track": track.isEmpty ? .null : .string(track),
            "title": track.isEmpty
                ? .null : .string((track as NSString).lastPathComponent),
            "isPlaying": .bool(payload["isPlaying"] as? Bool ?? false),
            "elapsedSeconds": .double(payload["elapsed"] as? Double ?? 0),
            "durationSeconds": .double(payload["duration"] as? Double ?? 0),
            "volume": .double(payload["volume"] as? Double ?? 0),
            "looping": .bool(payload["looping"] as? Bool ?? false),
            "shuffling": .bool(payload["shuffling"] as? Bool ?? false),
        ])
    }

    static func command(_ action: String, extra: [String: Any] = [:]) throws {
        try requireExtension()
        var info: [String: Any] = ["action": action]
        info.merge(extra) { first, _ in first }
        AppBridge.post(IPC.Name.musicCommand, userInfo: info)
    }
}

struct MusicStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status", abstract: "What is playing right now.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    func run() async throws {
        try await execute {
            let state = try await MusicBridge.state()
            guard !json else {
                CLIOut.json(state)
                return
            }
            guard case let .object(fields) = state else { return }
            let playing = fields["isPlaying"] == .bool(true)
            guard case let .string(title)? = fields["title"] else {
                CLIOut.out("nothing loaded")
                return
            }
            var elapsed = 0.0
            var duration = 0.0
            if case let .double(value)? = fields["elapsedSeconds"] { elapsed = value }
            if case let .double(value)? = fields["durationSeconds"] { duration = value }
            CLIOut.out(
                "\(playing ? "playing" : "paused")  \(title)  "
                    + "\(clock(elapsed))/\(clock(duration))")
        }
    }

    private func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct MusicPlayCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "play", abstract: "Resume playback.")

    func run() async throws {
        try await execute {
            try MusicBridge.command("resume")
            CLIOut.out("resumed")
        }
    }
}

struct MusicPauseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pause", abstract: "Pause playback.")

    func run() async throws {
        try await execute {
            try MusicBridge.command("pause")
            CLIOut.out("paused")
        }
    }
}

struct MusicToggleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toggle", abstract: "Toggle play and pause.")

    func run() async throws {
        try await execute {
            try MusicBridge.command("playPause")
            CLIOut.out("toggled")
        }
    }
}

struct MusicNextCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "next", abstract: "Skip to the next track.")

    func run() async throws {
        try await execute {
            try MusicBridge.command("next")
            CLIOut.out("skipped")
        }
    }
}

struct MusicPreviousCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "previous", abstract: "Go back to the previous track.",
        aliases: ["prev"])

    func run() async throws {
        try await execute {
            try MusicBridge.command("previous")
            CLIOut.out("back")
        }
    }
}

struct MusicVolumeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "volume", abstract: "Set the player volume from 0 to 1.")

    @Argument(help: "A number between 0 and 1.")
    var level: Double

    func run() async throws {
        try await execute {
            guard level >= 0, level <= 1 else {
                throw CLIFailure("volume must be between 0 and 1")
            }
            try MusicBridge.command("volume", extra: ["value": level])
            CLIOut.out(String(format: "volume %.2f", level))
        }
    }
}
