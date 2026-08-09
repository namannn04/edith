import Foundation

public struct MachineMount: Codable, Equatable, Sendable {
    public var machineID: UUID?
    public var target: String
    public var remotePath: String
    public var mountPoint: String
    public var isReadOnly: Bool

    public init(
        machineID: UUID? = nil, target: String, remotePath: String, mountPoint: String,
        isReadOnly: Bool = false
    ) {
        self.machineID = machineID
        self.target = target
        self.remotePath = remotePath
        self.mountPoint = mountPoint
        self.isReadOnly = isReadOnly
    }

    public var source: String { "\(target):\(remotePath)" }
}

public struct MountedVolume: Equatable, Sendable {
    public var source: String
    public var mountPoint: String
    public var kinds: [String]

    public init(source: String, mountPoint: String, kinds: [String]) {
        self.source = source
        self.mountPoint = mountPoint
        self.kinds = kinds
    }

    public var isReadOnly: Bool { kinds.contains("read-only") }
    public var looksLikeFUSE: Bool { kinds.contains { $0.contains("fuse") } }
}

public enum MachineMountError: LocalizedError, Equatable {
    case toolMissing
    case alreadyMounted(String)
    case notMounted(String)
    case mountPointBusy(String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .toolMissing:
            return "sshfs is not installed on this Mac."
        case let .alreadyMounted(path):
            return "That machine is already mounted at \(path)."
        case let .notMounted(name):
            return "\(name) is not mounted."
        case let .mountPointBusy(path):
            return "\(path) already has something in it."
        case let .failed(message):
            return message.isEmpty ? "The mount failed." : message
        }
    }

    public var hint: String? {
        switch self {
        case .toolMissing:
            return "install FUSE-T, which needs no kernel extension: "
                + "brew install --cask macos-fuse-t/cask/fuse-t "
                + "macos-fuse-t/cask/fuse-t-sshfs"
        case .mountPointBusy:
            return "pick another folder with --at, or empty that one"
        default:
            return nil
        }
    }
}

public enum MachineMounts {
    nonisolated(unsafe) public static var root: URL =
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Edith")

    public static let toolName = "sshfs"

    public static var recordsFile: URL { MachinePaths.dir.appendingPathComponent("mounts.json") }

    public static func folderName(for machine: Machine) -> String {
        let cleaned = machine.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? machine.id.uuidString : cleaned
    }

    public static func mountPoint(for machine: Machine) -> URL {
        root.appendingPathComponent(folderName(for: machine))
    }

    public static func executable() -> URL? {
        CLIToolEnvironment.executable(named: toolName)
    }

    public static var isAvailable: Bool { executable() != nil }

    public static func parse(_ output: String) -> [MountedVolume] {
        output.split(separator: "\n").compactMap { line in
            let text = String(line)
            guard let separator = text.range(of: " on ") else { return nil }
            let rest = String(text[separator.upperBound...])
            guard let optionsStart = rest.range(of: " (", options: .backwards) else { return nil }
            let options = String(rest[optionsStart.upperBound...])
                .replacingOccurrences(of: ")", with: "")
            return MountedVolume(
                source: String(text[text.startIndex..<separator.lowerBound]),
                mountPoint: String(rest[rest.startIndex..<optionsStart.lowerBound]),
                kinds: options.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                })
        }
    }

    public static func mount(for machine: Machine, in mounts: [MachineMount]) -> MachineMount? {
        mounts.first { $0.machineID == machine.id || $0.target == machine.sshTarget }
    }

    public static func adopted(_ volume: MountedVolume) -> MachineMount? {
        guard volume.looksLikeFUSE, let colon = volume.source.firstIndex(of: ":") else {
            return nil
        }
        return MachineMount(
            target: String(volume.source[volume.source.startIndex..<colon]),
            remotePath: String(volume.source[volume.source.index(after: colon)...]),
            mountPoint: volume.mountPoint, isReadOnly: volume.isReadOnly)
    }

    public static func reconcile(records: [MachineMount], with volumes: [MountedVolume])
        -> [MachineMount]
    {
        let byPoint = Dictionary(
            volumes.map { ($0.mountPoint, $0) }, uniquingKeysWith: { first, _ in first })
        var live = records.compactMap { record -> MachineMount? in
            guard let volume = byPoint[record.mountPoint] else { return nil }
            var updated = record
            updated.isReadOnly = volume.isReadOnly || record.isReadOnly
            return updated
        }
        let known = Set(live.map(\.mountPoint))
        live += volumes.compactMap { volume in
            guard !known.contains(volume.mountPoint) else { return nil }
            return adopted(volume)
        }
        return live
    }

    public static func volumes() async -> [MountedVolume] {
        parse(await run(URL(fileURLWithPath: "/sbin/mount"), []).output)
    }

    public static func list() async -> [MachineMount] {
        let live = reconcile(records: records(), with: await volumes())
        remember(live.filter { $0.machineID != nil })
        return live
    }

    public static func current(for machine: Machine) async -> MachineMount? {
        mount(for: machine, in: await list())
    }

    public static func options(
        machine: Machine, readOnly: Bool, uid: uid_t = getuid(), gid: gid_t = getgid(),
        minimal: Bool = false
    ) -> [String] {
        var options = [
            "ControlPath=\(MachinePaths.socketFile(for: machine.id).path)",
            "ControlMaster=no",
            "BatchMode=yes",
            "reconnect",
            "ServerAliveInterval=15",
            "ServerAliveCountMax=3",
        ]
        if !minimal {
            options += [
                "volname=\(folderName(for: machine))",
                "defer_permissions",
                "noappledouble",
                "noapplexattr",
                "idmap=user",
                "uid=\(uid)",
                "gid=\(gid)",
            ]
        }
        if readOnly { options.append("ro") }
        return options
    }

    public static func mountArguments(
        machine: Machine, remotePath: String, mountPoint: String, readOnly: Bool,
        uid: uid_t = getuid(), gid: gid_t = getgid(), minimal: Bool = false
    ) -> [String] {
        var options = options(
            machine: machine, readOnly: readOnly, uid: uid, gid: gid, minimal: minimal)
        var arguments = ["\(machine.sshTarget):\(remotePath)", mountPoint]
        if case .manual = machine.source {
            arguments += ["-p", String(machine.port)]
            if case let .keyFile(path, _) = machine.auth {
                options += [
                    "IdentityFile=\(SSHConfigFile.expandTilde(path))",
                    "IdentitiesOnly=yes",
                ]
            }
        }
        for option in options { arguments += ["-o", option] }
        return arguments
    }

    @discardableResult
    public static func mount(
        machine: Machine, remotePath: String, at mountPoint: URL? = nil, readOnly: Bool = false
    ) async throws -> MachineMount {
        guard let tool = executable() else { throw MachineMountError.toolMissing }
        if let existing = await current(for: machine) {
            throw MachineMountError.alreadyMounted(existing.mountPoint)
        }
        let destination = mountPoint ?? Self.mountPoint(for: machine)
        try prepare(destination)
        var complaint = ""
        for minimal in [false, true] {
            let result = await run(
                tool,
                mountArguments(
                    machine: machine, remotePath: remotePath, mountPoint: destination.path,
                    readOnly: readOnly, minimal: minimal))
            if let landed = await settled(machine: machine, at: destination, remotePath: remotePath)
            {
                remember(records().filter { $0.machineID != machine.id } + [landed])
                return landed
            }
            complaint = explain(result)
        }
        discardEmptyFolder(at: destination.path)
        throw MachineMountError.failed(complaint)
    }

    @discardableResult
    public static func unmount(machine: Machine) async throws -> MachineMount {
        guard let existing = await current(for: machine) else {
            throw MachineMountError.notMounted(machine.name)
        }
        var result = await run(URL(fileURLWithPath: "/sbin/umount"), [existing.mountPoint])
        if result.status != 0 {
            result = await run(
                URL(fileURLWithPath: "/usr/sbin/diskutil"),
                ["unmount", "force", existing.mountPoint])
        }
        guard await current(for: machine) == nil else {
            throw MachineMountError.failed(explain(result))
        }
        remember(records().filter { $0.mountPoint != existing.mountPoint })
        discardEmptyFolder(at: existing.mountPoint)
        return existing
    }

    static func settled(machine: Machine, at destination: URL, remotePath: String) async
        -> MachineMount?
    {
        for _ in 0..<10 {
            let volumes = await volumes()
            if let volume = volumes.first(where: { $0.mountPoint == destination.path }) {
                return MachineMount(
                    machineID: machine.id, target: machine.sshTarget, remotePath: remotePath,
                    mountPoint: destination.path, isReadOnly: volume.isReadOnly)
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        return nil
    }

    static func prepare(_ mountPoint: URL) throws {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: mountPoint.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue,
                (try? fm.contentsOfDirectory(atPath: mountPoint.path))?.isEmpty != false
            else { throw MachineMountError.mountPointBusy(mountPoint.path) }
            return
        }
        do {
            try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        } catch {
            throw MachineMountError.failed(error.localizedDescription)
        }
    }

    static func records() -> [MachineMount] {
        guard let data = try? Data(contentsOf: recordsFile) else { return [] }
        return (try? JSONDecoder().decode([MachineMount].self, from: data)) ?? []
    }

    static func remember(_ mounts: [MachineMount]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(mounts.filter { $0.machineID != nil }) else { return }
        try? FileManager.default.createDirectory(
            at: MachinePaths.dir, withIntermediateDirectories: true)
        try? data.write(to: recordsFile, options: .atomic)
    }

    private static func discardEmptyFolder(at path: String) {
        let fm = FileManager.default
        guard path.hasPrefix(root.path + "/"),
            (try? fm.contentsOfDirectory(atPath: path))?.isEmpty == true
        else { return }
        try? fm.removeItem(atPath: path)
    }

    private static func explain(_ result: (status: Int32, output: String)) -> String {
        let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else {
            return trimmed.split(separator: "\n").last.map(String.init) ?? trimmed
        }
        return "sshfs exited with status \(result.status) and said nothing"
    }

    private static func run(_ executable: URL, _ arguments: [String]) async -> (
        status: Int32, output: String
    ) {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.environment = CLIToolEnvironment.sanitized()
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.standardInput = FileHandle.nullDevice
            guard (try? process.run()) != nil else {
                return (Int32(-1), "\(executable.lastPathComponent) could not be started")
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }.value
    }
}
