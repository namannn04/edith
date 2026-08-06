import Foundation

public enum ArgumentKind: Equatable, Sendable {
    case machine
    case configKey
    case configValue
    case extensionID
    case permission
    case shell
    case group
    case usageRange
    case localPath
    case remotePath
    case container
    case free
}

public struct CommandNode: Equatable, Sendable {
    public let name: String
    public let summary: String
    public let options: [String]
    public let arguments: [ArgumentKind]
    public let children: [CommandNode]

    public init(
        _ name: String, _ summary: String, options: [String] = [],
        arguments: [ArgumentKind] = [], children: [CommandNode] = []
    ) {
        self.name = name
        self.summary = summary
        self.options = options
        self.arguments = arguments
        self.children = children
    }

    public func child(_ name: String) -> CommandNode? {
        children.first { $0.name == name }
    }
}

public enum CommandTree {
    public static let common = ["--json", "--help"]

    public static let root = CommandNode(
        "ed", "The command line for Edith.", options: ["--help", "--version"],
        children: [
            CommandNode("guide", "Print the built-in manual.", arguments: [.free]),
            CommandNode("schema", "Print the JSON Schema for the config document.", options: []),
            CommandNode("version", "Print the Edith CLI version.", options: common),
            CommandNode(
                "completions", "Generate or install shell completions.",
                arguments: [.shell],
                children: [
                    CommandNode("install", "Install completions for the detected shells.")
                ]),
            CommandNode(
                "install", "Link ed, edh and edith into a directory on PATH.",
                options: ["--json", "--directory"]),
            CommandNode(
                "uninstall", "Remove the ed, edh and edith links.", options: ["--json"]),
            CommandNode(
                "config", "Read and write every setting the UI exposes.",
                children: [
                    CommandNode(
                        "ls", "List settings and their current values.",
                        options: ["--json", "--group", "--changed"], arguments: [.group]),
                    CommandNode(
                        "get", "Print one setting.", options: common, arguments: [.configKey]),
                    CommandNode(
                        "set", "Write one setting.", options: ["--json"],
                        arguments: [.configKey, .configValue]),
                    CommandNode(
                        "unset", "Restore one setting to its default.", options: ["--json"],
                        arguments: [.configKey]),
                    CommandNode(
                        "describe", "Explain one setting.", options: common,
                        arguments: [.configKey]),
                    CommandNode(
                        "export", "Print changed settings as one JSON document.",
                        options: ["--defaults"]),
                    CommandNode(
                        "import", "Apply a JSON document of settings.",
                        options: ["--json", "--dry-run"], arguments: [.localPath]),
                ]),
            CommandNode(
                "extensions", "Turn Edith's extensions on and off.",
                children: [
                    CommandNode("ls", "List extensions.", options: common),
                    CommandNode(
                        "enable", "Turn an extension on.", options: ["--json"],
                        arguments: [.extensionID]),
                    CommandNode(
                        "disable", "Turn an extension off.", options: ["--json"],
                        arguments: [.extensionID]),
                    CommandNode(
                        "info", "Describe one extension.", options: common,
                        arguments: [.extensionID]),
                ]),
            CommandNode(
                "permissions", "Inspect and request Edith's macOS permissions.",
                children: [
                    CommandNode("ls", "List permissions.", options: common),
                    CommandNode(
                        "request", "Ask the app to request a permission.", options: ["--json"],
                        arguments: [.permission]),
                    CommandNode(
                        "refresh", "Ask the app to re-read the real TCC state.",
                        options: ["--json"]),
                ]),
            CommandNode(
                "usage", "Agent usage, token counts, cost and rate limits.",
                children: [
                    CommandNode(
                        "limits", "Session and weekly limits per provider.",
                        options: common),
                    CommandNode(
                        "summary", "Cost and tokens over a window.",
                        options: ["--json", "--range", "--source"], arguments: [.usageRange]),
                    CommandNode(
                        "daily", "Per-day cost and tokens.",
                        options: ["--json", "--range", "--source"]),
                    CommandNode(
                        "models", "Cost and tokens per model.",
                        options: ["--json", "--range", "--source"]),
                    CommandNode(
                        "projects", "Cost and tokens per project.",
                        options: ["--json", "--range"]),
                    CommandNode(
                        "sources", "The agents that produced the history.",
                        options: common),
                    CommandNode(
                        "refresh", "Ask the running app to re-collect usage.",
                        options: ["--json"]),
                ]),
            CommandNode(
                "system", "Metrics for this Mac.",
                children: [
                    CommandNode(
                        "stats", "Sample CPU, memory, load and network.",
                        options: ["--json", "--follow", "--interval", "--processes"]),
                    CommandNode("disks", "Mounted volumes and their free space.", options: common),
                ]),
            CommandNode(
                "music", "What is playing, and playback control.",
                children: [
                    CommandNode("status", "What is playing right now.", options: common),
                    CommandNode("play", "Resume playback.", options: ["--json"]),
                    CommandNode("pause", "Pause playback.", options: ["--json"]),
                    CommandNode("toggle", "Toggle play and pause.", options: ["--json"]),
                    CommandNode("next", "Skip to the next track.", options: ["--json"]),
                    CommandNode("previous", "Go back to the previous track.", options: ["--json"]),
                    CommandNode(
                        "volume", "Set the player volume from 0 to 1.",
                        options: ["--json"]),
                ]),
            CommandNode(
                "calendar", "Your schedule.",
                children: [
                    CommandNode("ls", "Upcoming events.", options: ["--json", "--days"])
                ]),
            CommandNode(
                "machines", "The computers Edith can reach over SSH.",
                children: [
                    CommandNode("ls", "List configured machines.", options: common),
                    CommandNode(
                        "show", "One machine, with live facts.", options: common,
                        arguments: [.machine]),
                    CommandNode(
                        "metrics", "Sample a machine.",
                        options: ["--json", "--follow", "--interval", "--processes"],
                        arguments: [.machine]),
                    CommandNode(
                        "exec", "Run a command on a machine.", options: ["--json"],
                        arguments: [.machine, .free]),
                    CommandNode(
                        "files", "Browse and transfer files.",
                        children: [
                            CommandNode(
                                "ls", "List a remote directory.", options: common,
                                arguments: [.machine, .remotePath]),
                            CommandNode(
                                "get", "Download a file.", options: ["--json"],
                                arguments: [.machine, .remotePath, .localPath]),
                            CommandNode(
                                "put", "Upload a file.", options: ["--json"],
                                arguments: [.machine, .localPath, .remotePath]),
                        ]),
                    CommandNode(
                        "docker", "Containers on a machine.",
                        children: [
                            CommandNode(
                                "ps", "List containers.", options: ["--json", "--all"],
                                arguments: [.machine]),
                            CommandNode(
                                "images", "List images.", options: common,
                                arguments: [.machine]),
                            CommandNode(
                                "volumes", "List volumes.", options: common,
                                arguments: [.machine]),
                            CommandNode(
                                "networks", "List networks.", options: common,
                                arguments: [.machine]),
                            CommandNode(
                                "df", "Disk usage by object type.", options: common,
                                arguments: [.machine]),
                            CommandNode(
                                "logs", "Container logs.",
                                options: ["--tail", "--follow"],
                                arguments: [.machine, .container]),
                            CommandNode(
                                "inspect", "Raw inspect output.", options: ["--json"],
                                arguments: [.machine, .container]),
                            CommandNode(
                                "start", "Start a container.", options: ["--json"],
                                arguments: [.machine, .container]),
                            CommandNode(
                                "stop", "Stop a container.", options: ["--json"],
                                arguments: [.machine, .container]),
                            CommandNode(
                                "restart", "Restart a container.", options: ["--json"],
                                arguments: [.machine, .container]),
                            CommandNode(
                                "rm", "Remove a container.", options: ["--json"],
                                arguments: [.machine, .container]),
                        ]),
                    CommandNode(
                        "services", "systemd units on a machine.", options: ["--json", "--failed"],
                        arguments: [.machine]),
                    CommandNode(
                        "connect", "Open the shared SSH connection.", options: ["--json"],
                        arguments: [.machine]),
                    CommandNode(
                        "disconnect", "Close the shared SSH connection.", options: ["--json"],
                        arguments: [.machine]),
                ]),
        ])

    public static var topLevelNames: [String] {
        root.children.map(\.name)
    }

    public static func node(at path: [String]) -> CommandNode? {
        var current = root
        for name in path {
            guard let next = current.child(name) else { return nil }
            current = next
        }
        return current
    }
}
