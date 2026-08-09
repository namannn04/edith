import ArgumentParser
import EdithKit
import Foundation

enum MountBridge {
    static func failure(_ error: Error, machine: Machine) -> CLIFailure {
        guard let mount = error as? MachineMountError else {
            return CLIFailure("\(machine.name): \(error.localizedDescription)")
        }
        let message = mount.errorDescription ?? "the mount failed"
        switch mount {
        case .toolMissing, .notMounted:
            return CLIFailure.unavailable(message, hint: mount.hint)
        default:
            return CLIFailure(message, hint: mount.hint)
        }
    }

    static func report(_ mount: MachineMount, machine: Machine) -> JSONValue {
        .object([
            "machine": .string(machine.name),
            "source": .string(mount.source),
            "remotePath": .string(mount.remotePath),
            "mountPoint": .string(mount.mountPoint),
            "readOnly": .bool(mount.isReadOnly),
        ])
    }
}

struct MachinesMountCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mount",
        abstract: "Mount a machine's file system on this Mac.",
        discussion: """
            The folder appears in Finder like a disk, so every local tool sees the machine's
            files: `ls ~/Edith/tuf`, `open`, an editor, `rsync`. It rides the same SSH
            connection the app and `ed` already share, so nothing asks for the password
            twice.

            This needs macFUSE and sshfs on this Mac:
            `brew install --cask macfuse && brew install gromgit/fuse/sshfs-mac`.
            """)

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(name: .long, help: "Mount it read-only.")
    var readOnly = false

    @Option(name: .long, help: "Where to mount it. Defaults to ~/Edith/<machine>.")
    var at: String?

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    @Argument(help: "Remote directory to mount. Defaults to the home directory.")
    var path: String?

    func run() async throws {
        try await execute {
            let runner = try await MachineResolver.runner(machine)
            let remote = try await resolvedRemotePath(runner)
            let destination = at.map { URL(fileURLWithPath: $0.expandingTilde()) }
            do {
                let mounted = try await MachineMounts.mount(
                    machine: runner.machine, remotePath: remote, at: destination,
                    readOnly: readOnly)
                guard !json else {
                    CLIOut.json(MountBridge.report(mounted, machine: runner.machine))
                    return
                }
                CLIOut.out("\(mounted.source)  ->  \(mounted.mountPoint)")
            } catch {
                throw MountBridge.failure(error, machine: runner.machine)
            }
        }
    }

    private func resolvedRemotePath(_ runner: RemoteRunner) async throws -> String {
        if let path, !path.isEmpty { return path }
        if let stored = MachineWorkingDirectory.load(machineID: runner.machine.id) {
            return stored
        }
        let home = try await runner.text("printf %s \"$HOME\"", timeout: 15)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return home.isEmpty ? "/" : home
    }
}

struct MachinesUnmountCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "unmount", abstract: "Unmount a machine's file system.",
        aliases: ["umount"])

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Argument(help: "Machine name, ssh alias or id.")
    var machine: String

    func run() async throws {
        try await execute {
            let found = try MachineResolver.machine(machine)
            do {
                let released = try await MachineMounts.unmount(machine: found)
                guard !json else {
                    CLIOut.json(MountBridge.report(released, machine: found))
                    return
                }
                CLIOut.out("unmounted \(released.mountPoint)")
            } catch {
                throw MountBridge.failure(error, machine: found)
            }
        }
    }
}

struct MachinesMountsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mounts", abstract: "Every machine file system mounted on this Mac.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    func run() async throws {
        try await execute {
            let machines = MachineDirectory.load()
            let mounts = await MachineMounts.list()
            let named = mounts.map { mount in
                (machines.first { $0.sshTarget == mount.target }?.name ?? mount.target, mount)
            }
            guard !json else {
                CLIOut.json(
                    .array(
                        named.map { name, mount in
                            .object([
                                "machine": .string(name),
                                "source": .string(mount.source),
                                "remotePath": .string(mount.remotePath),
                                "mountPoint": .string(mount.mountPoint),
                                "readOnly": .bool(mount.isReadOnly),
                            ])
                        }))
                return
            }
            guard !named.isEmpty else {
                CLIOut.note("nothing is mounted; mount one with `ed machines mount <machine>`")
                return
            }
            let rows = named.map { name, mount in
                [name, mount.remotePath, mount.mountPoint, mount.isReadOnly ? "ro" : "rw"]
            }
            CLIOut.out(
                TextTable.render(headers: ["MACHINE", "REMOTE", "AT", "MODE"], rows: rows))
        }
    }
}
