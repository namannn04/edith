import ArgumentParser
import EdithKit
import Foundation

enum MachineEditing {
    static func port(_ value: Int) throws -> Int {
        guard (1...65535).contains(value) else {
            throw CLIFailure("--port must be between 1 and 65535")
        }
        return value
    }

    static func auth(keyFile: String?, agent: Bool) throws -> MachineAuth? {
        if agent, keyFile != nil {
            throw CLIFailure("--agent and --key are different answers to the same question")
        }
        if agent { return .agent }
        guard let keyFile else { return nil }
        let path = (keyFile as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIFailure.notFound(
                "there is no key file at \(path)",
                hint: "point --key at a private key, or pass --agent to use the SSH agent")
        }
        return .keyFile(path: path, hasPassphrase: false)
    }

    static func rejectDuplicate(name: String, excluding id: UUID?, in machines: [Machine]) throws {
        let taken = machines.contains {
            $0.id != id && $0.name.lowercased() == name.lowercased()
        }
        guard taken else { return }
        throw CLIFailure(
            "a machine called \(name) already exists",
            hint: "pick another name, or edit the existing one with `ed machines edit \(name)`")
    }

    static func describe(_ machine: Machine) {
        CLIOut.out(machine.name)
        CLIOut.out("  target   \(machine.subtitle)")
        CLIOut.out("  auth     \(machine.auth.displayName)")
        if let mac = machine.wakeMACAddress { CLIOut.out("  wake     \(mac)") }
    }
}

struct MachinesAddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a machine to Edith's list.",
        discussion: """
            The machine appears in the app straight away. Password authentication is not
            offered here because the password belongs in the login keychain under the app's
            own identity; add those in Edith under Machines.
            """)

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "What to call it.")
    var name: String

    @Option(help: "Hostname or address to reach it at.")
    var host: String

    @Option(help: "SSH port.")
    var port: Int = 22

    @Option(help: "Username to log in as.")
    var user: String = ""

    @Option(help: "Private key to authenticate with, instead of the SSH agent.")
    var key: String?

    @Option(help: "Treat this as an entry from your ssh config with this alias.")
    var alias: String?

    @Option(help: "MAC address to send a wake-on-LAN packet to.")
    var mac: String?

    func run() async throws {
        try await execute {
            let existing = MachineRegistry.machines()
            try MachineEditing.rejectDuplicate(name: name, excluding: nil, in: existing)
            let machine = Machine(
                name: name, host: host, port: try MachineEditing.port(port), username: user,
                auth: try MachineEditing.auth(keyFile: key, agent: key == nil) ?? .agent,
                source: alias.map { MachineSource.sshConfigAlias($0) } ?? .manual,
                wakeMACAddress: mac)
            MachineRegistry.add(machine)
            AppBridge.post(IPC.Name.machinesChanged)
            guard !json else {
                CLIOut.json(MachineDirectory.summary(machine))
                return
            }
            CLIOut.out("added \(machine.name)")
            MachineEditing.describe(machine)
        }
    }
}

struct MachinesEditCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "edit", abstract: "Change a machine already on the list.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Option(help: "Rename it.")
    var name: String?

    @Option(help: "Hostname or address to reach it at.")
    var host: String?

    @Option(help: "SSH port.")
    var port: Int?

    @Option(help: "Username to log in as.")
    var user: String?

    @Option(help: "Private key to authenticate with.")
    var key: String?

    @Flag(help: "Authenticate with the SSH agent instead of a key file.")
    var agent = false

    @Option(help: "MAC address to send a wake-on-LAN packet to. Pass an empty value to clear.")
    var mac: String?

    func run() async throws {
        try await execute {
            var target = try MachineResolver.machine(machine)
            let all = MachineRegistry.machines()
            if let name {
                try MachineEditing.rejectDuplicate(name: name, excluding: target.id, in: all)
                target.name = name
            }
            if let host { target.host = host }
            if let port { target.port = try MachineEditing.port(port) }
            if let user { target.username = user }
            if let auth = try MachineEditing.auth(keyFile: key, agent: agent) { target.auth = auth }
            if let mac { target.wakeMACAddress = mac.isEmpty ? nil : mac }
            MachineRegistry.update(target)
            AppBridge.post(IPC.Name.machinesChanged)
            guard !json else {
                CLIOut.json(MachineDirectory.summary(target))
                return
            }
            CLIOut.out("updated \(target.name)")
            MachineEditing.describe(target)
        }
    }
}

struct MachinesRemoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm",
        abstract: "Forget a machine, its forwards, its snippets and its stored secrets.",
        aliases: ["remove"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(help: "Actually remove it. Without this nothing is touched.")
    var yes = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    func run() async throws {
        try await execute {
            let target = try MachineResolver.machine(machine)
            let contents = MachineRegistry.load()
            let forwards = MachineRegistry.forwards(machineID: target.id, in: contents.forwards)
            let snippets = contents.snippets.filter { $0.machineID == target.id }
            guard yes else {
                guard !json else {
                    CLIOut.json(
                        .object([
                            "machine": MachineDirectory.summary(target),
                            "removed": .bool(false),
                            "forwards": .int(forwards.count),
                            "snippets": .int(snippets.count),
                        ]))
                    return
                }
                CLIOut.out(
                    "would remove \(target.name), \(forwards.count) forward(s) and "
                        + "\(snippets.count) snippet(s)")
                CLIOut.note("nothing was removed; pass --yes to go ahead")
                return
            }
            MachineRegistry.remove(id: target.id)
            AppBridge.post(IPC.Name.machinesChanged)
            guard !json else {
                CLIOut.json(
                    .object([
                        "machine": MachineDirectory.summary(target),
                        "removed": .bool(true),
                        "forwards": .int(forwards.count),
                        "snippets": .int(snippets.count),
                    ]))
                return
            }
            CLIOut.out("removed \(target.name)")
        }
    }
}

struct MachinesForwardsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "forwards",
        abstract: "The port forwards saved for a machine.",
        subcommands: [
            MachinesForwardsListCommand.self, MachinesForwardsAddCommand.self,
            MachinesForwardsRemoveCommand.self,
        ],
        defaultSubcommand: MachinesForwardsListCommand.self,
        aliases: ["forward"])
}

enum ForwardBridge {
    static func forwards(_ query: String) throws -> (machine: Machine, all: [PortForward]) {
        let machine = try MachineResolver.machine(query)
        let all = MachineRegistry.forwards(
            machineID: machine.id, in: MachineRegistry.forwards()
        ).sorted { $0.localPort < $1.localPort }
        return (machine, all)
    }

    static func json(_ forward: PortForward, index: Int) -> JSONValue {
        .object([
            "index": .int(index),
            "id": .string(forward.id.uuidString),
            "title": .string(forward.displayName),
            "localPort": .int(forward.localPort),
            "remoteHost": .string(forward.remoteHost),
            "remotePort": .int(forward.remotePort),
            "spec": .string(forward.forwardSpec),
        ])
    }
}

struct MachinesForwardsListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls", abstract: "List a machine's port forwards.", aliases: ["list"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    func run() async throws {
        try await execute {
            let found = try ForwardBridge.forwards(machine)
            guard !json else {
                CLIOut.json(
                    .array(
                        found.all.enumerated().map { ForwardBridge.json($1, index: $0 + 1) }))
                return
            }
            guard !found.all.isEmpty else {
                CLIOut.note("\(found.machine.name) has no saved forwards")
                return
            }
            CLIOut.out(
                TextTable.render(
                    headers: ["#", "TITLE", "LOCAL", "REMOTE"],
                    rows: found.all.enumerated().map { offset, forward in
                        [
                            String(offset + 1), forward.title,
                            String(forward.localPort),
                            "\(forward.remoteHost):\(forward.remotePort)",
                        ]
                    }))
        }
    }
}

struct MachinesForwardsAddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add", abstract: "Save a port forward for a machine.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Option(help: "Port to open on this Mac.")
    var local: Int

    @Option(help: "Port to reach on the far side.")
    var remote: Int

    @Option(help: "Host the far side should connect to.")
    var remoteHost: String = "localhost"

    @Option(help: "What to call it.")
    var title: String = ""

    func run() async throws {
        try await execute {
            let target = try MachineResolver.machine(machine)
            let forward = PortForward(
                machineID: target.id, localPort: try MachineEditing.port(local),
                remoteHost: remoteHost, remotePort: try MachineEditing.port(remote),
                title: title)
            let taken = MachineRegistry.forwards(
                machineID: target.id, in: MachineRegistry.forwards()
            ).contains { $0.localPort == forward.localPort }
            guard !taken else {
                throw CLIFailure(
                    "\(target.name) already forwards local port \(forward.localPort)",
                    hint: "run `ed machines forwards ls \(target.name)` to see them")
            }
            MachineRegistry.addForward(forward)
            AppBridge.post(IPC.Name.machinesChanged)
            guard !json else {
                CLIOut.json(ForwardBridge.json(forward, index: 0))
                return
            }
            CLIOut.out("added \(forward.forwardSpec) on \(target.name)")
        }
    }
}

struct MachinesForwardsRemoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm", abstract: "Forget one saved port forward.", aliases: ["remove"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "The forward number, counting from 1.")
    var index: Int

    func run() async throws {
        try await execute {
            let found = try ForwardBridge.forwards(machine)
            guard index >= 1, index <= found.all.count else {
                throw CLIFailure.notFound(
                    "there is no forward \(index) on \(found.machine.name)",
                    hint: "it has \(found.all.count), numbered from 1")
            }
            let forward = found.all[index - 1]
            MachineRegistry.removeForward(id: forward.id)
            AppBridge.post(IPC.Name.machinesChanged)
            guard !json else {
                CLIOut.json(
                    .object([
                        "removed": ForwardBridge.json(forward, index: index),
                        "remaining": .int(found.all.count - 1),
                    ]))
                return
            }
            CLIOut.out("removed \(forward.forwardSpec) from \(found.machine.name)")
        }
    }
}

struct MachinesSnippetsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snippets",
        abstract: "The saved commands a machine offers.",
        subcommands: [
            MachinesSnippetsListCommand.self, MachinesSnippetsAddCommand.self,
            MachinesSnippetsRemoveCommand.self,
        ],
        defaultSubcommand: MachinesSnippetsListCommand.self,
        aliases: ["snippet"])
}

enum SnippetBridge {
    static func snippets(_ query: String) throws -> (machine: Machine, all: [CommandSnippet]) {
        let machine = try MachineResolver.machine(query)
        let all = MachineRegistry.snippets(
            machineID: machine.id, in: MachineRegistry.snippets())
        return (machine, all)
    }

    static func json(_ snippet: CommandSnippet, index: Int) -> JSONValue {
        .object([
            "index": .int(index),
            "id": .string(snippet.id.uuidString),
            "title": .string(snippet.title),
            "command": .string(snippet.command),
            "sharedAcrossMachines": .bool(snippet.machineID == nil),
        ])
    }
}

struct MachinesSnippetsListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls", abstract: "List the snippets a machine offers.", aliases: ["list"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    func run() async throws {
        try await execute {
            let found = try SnippetBridge.snippets(machine)
            guard !json else {
                CLIOut.json(
                    .array(
                        found.all.enumerated().map { SnippetBridge.json($1, index: $0 + 1) }))
                return
            }
            guard !found.all.isEmpty else {
                CLIOut.note("\(found.machine.name) has no snippets")
                return
            }
            CLIOut.out(
                TextTable.render(
                    headers: ["#", "TITLE", "SCOPE", "COMMAND"],
                    rows: found.all.enumerated().map { offset, snippet in
                        [
                            String(offset + 1), snippet.title,
                            snippet.machineID == nil ? "shared" : "machine", snippet.command,
                        ]
                    }))
        }
    }
}

struct MachinesSnippetsAddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Save a command against a machine.",
        discussion: """
            Everything after the title is the command, verbatim, so `--shared` and `--json`
            have to come before the machine name: `ed machines snippets add --shared box
            logs journalctl -xe`.
            """)

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(help: "Offer it on every machine rather than just this one.")
    var shared = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "What to call it.")
    var title: String

    @Argument(parsing: .captureForPassthrough, help: "The command to save.")
    var command: [String]

    func run() async throws {
        try await execute {
            let target = try MachineResolver.machine(machine)
            let text = command.joined(separator: " ")
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw CLIFailure("a snippet needs a command to run")
            }
            let snippet = CommandSnippet(
                machineID: shared ? nil : target.id, title: title, command: text)
            MachineRegistry.addSnippet(snippet)
            AppBridge.post(IPC.Name.machinesChanged)
            guard !json else {
                CLIOut.json(SnippetBridge.json(snippet, index: 0))
                return
            }
            CLIOut.out("saved \(title) on \(shared ? "every machine" : target.name)")
        }
    }
}

struct MachinesSnippetsRemoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm", abstract: "Forget one snippet.", aliases: ["remove"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "The snippet number, counting from 1.")
    var index: Int

    func run() async throws {
        try await execute {
            let found = try SnippetBridge.snippets(machine)
            guard index >= 1, index <= found.all.count else {
                throw CLIFailure.notFound(
                    "there is no snippet \(index) on \(found.machine.name)",
                    hint: "it offers \(found.all.count), numbered from 1")
            }
            let snippet = found.all[index - 1]
            MachineRegistry.removeSnippet(id: snippet.id)
            AppBridge.post(IPC.Name.machinesChanged)
            guard !json else {
                CLIOut.json(
                    .object([
                        "removed": SnippetBridge.json(snippet, index: index),
                        "remaining": .int(found.all.count - 1),
                    ]))
                return
            }
            CLIOut.out("removed \(snippet.title)")
        }
    }
}
