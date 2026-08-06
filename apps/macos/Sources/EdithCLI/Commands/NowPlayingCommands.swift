import ArgumentParser
import EdithKit
import Foundation

struct NowPlayingCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "nowplaying",
        abstract: "The track Spotify or Apple Music is playing, and its transport.",
        discussion: """
            `ed music` drives Edith's own library. This drives whichever external
            player the Home widget is showing, so pausing here pauses Spotify.
            """,
        subcommands: [
            NowPlayingStatusCommand.self, NowPlayingPlayPauseCommand.self,
            NowPlayingNextCommand.self, NowPlayingPreviousCommand.self,
            NowPlayingVolumeCommand.self,
        ],
        defaultSubcommand: NowPlayingStatusCommand.self)
}

enum NowPlayingBridge {
    static func state(timeout: TimeInterval = 3) async throws -> JSONValue {
        try AppBridge.requireHelper("now playing control")
        guard
            let payload = await AppBridge.awaitReply(
                IPC.Name.nowPlayingState, timeout: timeout,
                trigger: { AppBridge.post(IPC.Name.requestNowPlayingState) })
        else {
            throw CLIFailure.unavailable("the app did not report a now playing state in time")
        }
        return json(payload)
    }

    static func json(_ payload: [AnyHashable: Any]) -> JSONValue {
        guard payload["present"] as? Bool ?? false else {
            return .object(["present": .bool(false)])
        }
        return .object([
            "present": .bool(true),
            "app": .string(payload["app"] as? String ?? ""),
            "appName": .string(payload["appName"] as? String ?? ""),
            "title": .string(payload["title"] as? String ?? ""),
            "artist": .string(payload["artist"] as? String ?? ""),
            "isPlaying": .bool(payload["isPlaying"] as? Bool ?? false),
        ])
    }

    static func send(_ action: String, value: Double? = nil) async throws -> JSONValue {
        try AppBridge.requireHelper("now playing control")
        var payload: [String: Any] = ["action": action]
        if let value { payload["value"] = value }
        let info = payload
        guard
            let payload = await AppBridge.awaitReply(
                IPC.Name.nowPlayingState, timeout: 3,
                trigger: { AppBridge.post(IPC.Name.nowPlayingCommand, userInfo: info) })
        else {
            throw CLIFailure.unavailable("the app did not confirm the command in time")
        }
        return json(payload)
    }

    static func describe(_ value: JSONValue) -> String {
        guard case let .object(fields) = value,
            case .bool(true)? = fields["present"]
        else { return "nothing playing" }
        func text(_ key: String) -> String {
            guard case let .string(value)? = fields[key] else { return "" }
            return value
        }
        var state = "paused"
        if case .bool(true)? = fields["isPlaying"] { state = "playing" }
        let artist = text("artist")
        let suffix = artist.isEmpty ? "" : "  \(artist)"
        return "\(state)  \(text("title"))\(suffix)  (\(text("appName")))"
    }
}

struct NowPlayingStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status", abstract: "What the external player is playing.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    func run() async throws {
        try await execute {
            let state = try await NowPlayingBridge.state()
            guard !json else {
                CLIOut.json(state)
                return
            }
            CLIOut.out(NowPlayingBridge.describe(state))
        }
    }
}

struct NowPlayingPlayPauseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toggle",
        abstract: "Toggle the external player between playing and paused.",
        aliases: ["playpause", "play", "pause"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    func run() async throws {
        try await execute {
            let state = try await NowPlayingBridge.send("playpause")
            guard !json else {
                CLIOut.json(state)
                return
            }
            CLIOut.out(NowPlayingBridge.describe(state))
        }
    }
}

struct NowPlayingNextCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "next", abstract: "Skip to the next track.")

    func run() async throws {
        try await execute {
            CLIOut.out(NowPlayingBridge.describe(try await NowPlayingBridge.send("next")))
        }
    }
}

struct NowPlayingPreviousCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "previous", abstract: "Go back to the previous track.",
        aliases: ["prev"])

    func run() async throws {
        try await execute {
            CLIOut.out(NowPlayingBridge.describe(try await NowPlayingBridge.send("previous")))
        }
    }
}

struct NowPlayingVolumeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "volume", abstract: "Set the external player volume from 0 to 1.")

    @Argument(help: "A number from 0 to 1.")
    var level: Double

    func run() async throws {
        try await execute {
            guard (0...1).contains(level) else {
                throw CLIFailure("volume must be between 0 and 1")
            }
            CLIOut.out(
                NowPlayingBridge.describe(
                    try await NowPlayingBridge.send("volume", value: level)))
        }
    }
}
