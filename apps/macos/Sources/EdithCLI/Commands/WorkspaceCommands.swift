import ArgumentParser
import EdithKit
import Foundation

struct MachinesWorkspaceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workspace",
        abstract: "The saved multi-pane layouts the Workspace view shows.",
        discussion: """
            A workspace is a saved arrangement of panes, each pointed at a machine and a
            screen. These read and write the same file the view does, so a layout built
            here shows up there and the other way round.
            """,
        subcommands: [
            WorkspaceListCommand.self, WorkspaceUseCommand.self, WorkspaceNewCommand.self,
            WorkspaceRenameCommand.self, WorkspaceRemoveCommand.self,
        ],
        defaultSubcommand: WorkspaceListCommand.self,
        aliases: ["workspaces"])
}

enum WorkspaceBridge {
    static func store() -> WorkspaceStore { WorkspaceStore.load() }

    static func layout(_ query: String, in store: WorkspaceStore) throws -> WorkspaceLayout {
        guard !store.layouts.isEmpty else {
            throw CLIFailure.unavailable(
                "no workspaces are saved",
                hint: "make one with `ed machines workspace new`")
        }
        let needle = query.lowercased()
        if let exact = store.layouts.first(where: { $0.name.lowercased() == needle }) {
            return exact
        }
        if let byID = store.layouts.first(where: { $0.id.uuidString.lowercased() == needle }) {
            return byID
        }
        let prefixed = store.layouts.filter { $0.name.lowercased().hasPrefix(needle) }
        if prefixed.count == 1, let only = prefixed.first { return only }
        if prefixed.count > 1 {
            throw CLIFailure.notFound(
                "\(query) matches more than one workspace",
                hint: prefixed.map(\.name).joined(separator: ", "))
        }
        throw CLIFailure.notFound(
            "no workspace called \(query)",
            hint: "known: " + store.layouts.map(\.name).joined(separator: ", "))
    }

    static func json(_ layout: WorkspaceLayout, current: Bool) -> JSONValue {
        .object([
            "id": .string(layout.id.uuidString),
            "name": .string(layout.name),
            "panes": .int(layout.paneCount),
            "machines": .int(layout.subscribedMachines().count),
            "current": .bool(current),
        ])
    }

    static func announce() {
        AppBridge.post(IPC.Name.machinesChanged)
    }

    static func write(_ store: WorkspaceStore) throws {
        do {
            try WorkspaceStore.save(store)
        } catch {
            throw CLIFailure("could not save the workspaces: \(error.localizedDescription)")
        }
        announce()
    }
}

struct WorkspaceListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls", abstract: "List the saved workspaces.", aliases: ["list"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    func run() async throws {
        try await execute {
            let store = WorkspaceBridge.store()
            let currentID = store.current?.id
            guard !json else {
                CLIOut.json(
                    .array(
                        store.layouts.map {
                            WorkspaceBridge.json($0, current: $0.id == currentID)
                        }))
                return
            }
            guard !store.layouts.isEmpty else {
                CLIOut.note("no workspaces are saved")
                return
            }
            CLIOut.out(
                TextTable.render(
                    headers: ["NAME", "PANES", "MACHINES", ""],
                    rows: store.layouts.map {
                        [
                            $0.name, String($0.paneCount),
                            String($0.subscribedMachines().count),
                            $0.id == currentID ? "current" : "",
                        ]
                    }))
        }
    }
}

struct WorkspaceUseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "use", abstract: "Make one workspace the current one.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Workspace name or id.")
    var workspace: String

    func run() async throws {
        try await execute {
            var store = WorkspaceBridge.store()
            let layout = try WorkspaceBridge.layout(workspace, in: store)
            store.currentID = layout.id
            try WorkspaceBridge.write(store)
            guard !json else {
                CLIOut.json(WorkspaceBridge.json(layout, current: true))
                return
            }
            CLIOut.out("now showing \(layout.name)")
        }
    }
}

struct WorkspaceNewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Build a workspace with one pane per machine.",
        discussion: """
            This is the Layout menu's presets as a command: name the machines and the
            screen each pane should show. With one machine you get a single pane, with
            several you get them tiled side by side.
            """)

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(help: "What each pane shows: overview, processes, docker, files or terminal.")
    var screen: String = "overview"

    @Option(help: "What to call it.")
    var name: String?

    @Argument(help: "Machines to give a pane each.")
    var machines: [String]

    func run() async throws {
        try await execute {
            guard !machines.isEmpty else { throw CLIFailure("name at least one machine") }
            guard let wanted = PaneScreen(rawValue: screen) else {
                throw CLIFailure.notFound(
                    "no screen called \(screen)",
                    hint: "screens: "
                        + PaneScreen.allCases.map(\.rawValue).joined(separator: ", "))
            }
            let resolved = try machines.map { try MachineResolver.machine($0) }
            let title = name ?? resolved.map(\.name).joined(separator: " + ")
            guard
                let layout = WorkspaceLayout.tiled(
                    machineIDs: resolved.map(\.id), screen: wanted, name: title)
            else { throw CLIFailure("could not build a layout from those machines") }
            var store = WorkspaceBridge.store()
            store.upsert(layout)
            try WorkspaceBridge.write(store)
            guard !json else {
                CLIOut.json(WorkspaceBridge.json(layout, current: true))
                return
            }
            CLIOut.out("made \(layout.name) with \(layout.paneCount) pane(s)")
        }
    }
}

struct WorkspaceRenameCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rename", abstract: "Rename a workspace.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Workspace name or id.")
    var workspace: String

    @Argument(help: "The new name.")
    var name: String

    func run() async throws {
        try await execute {
            var store = WorkspaceBridge.store()
            var layout = try WorkspaceBridge.layout(workspace, in: store)
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw CLIFailure("a workspace needs a name") }
            let was = layout.name
            layout.name = trimmed
            let currentID = store.currentID
            store.upsert(layout)
            store.currentID = currentID
            try WorkspaceBridge.write(store)
            guard !json else {
                CLIOut.json(WorkspaceBridge.json(layout, current: layout.id == currentID))
                return
            }
            CLIOut.out("renamed \(was) to \(trimmed)")
        }
    }
}

struct WorkspaceRemoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm", abstract: "Forget a workspace.", aliases: ["remove"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Workspace name or id.")
    var workspace: String

    func run() async throws {
        try await execute {
            var store = WorkspaceBridge.store()
            let layout = try WorkspaceBridge.layout(workspace, in: store)
            store.remove(layout.id)
            try WorkspaceBridge.write(store)
            guard !json else {
                CLIOut.json(
                    .object([
                        "removed": .string(layout.name),
                        "remaining": .int(store.layouts.count),
                    ]))
                return
            }
            CLIOut.out("removed \(layout.name)")
        }
    }
}
