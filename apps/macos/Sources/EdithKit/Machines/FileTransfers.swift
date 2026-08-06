import Foundation

public struct MachineItemsPayload: Codable, Equatable, Sendable {
    public var machineID: UUID
    public var paths: [String]
    public var isLocal: Bool

    public init(machineID: UUID, paths: [String], isLocal: Bool) {
        self.machineID = machineID
        self.paths = paths
        self.isLocal = isLocal
    }

    public static let typeIdentifier = "page.pulkit.edith.machine-items"

    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) -> MachineItemsPayload? {
        try? JSONDecoder().decode(MachineItemsPayload.self, from: data)
    }
}

public enum DropIntent: Equatable, Sendable {
    case moveWithinMachine([String])
    case copyWithinMachine([String])
    case transferBetweenMachines(from: UUID, paths: [String])
    case uploadLocalFiles([String])

    public var paths: [String] {
        switch self {
        case let .moveWithinMachine(paths), let .copyWithinMachine(paths):
            return paths
        case let .transferBetweenMachines(_, paths):
            return paths
        case let .uploadLocalFiles(paths):
            return paths
        }
    }
}

public enum DropResolver {
    public static func intent(
        payload: MachineItemsPayload?, fileURLPaths: [String], destinationMachine: UUID,
        optionHeld: Bool
    ) -> DropIntent? {
        if let payload, !payload.paths.isEmpty {
            if payload.machineID == destinationMachine {
                return optionHeld
                    ? .copyWithinMachine(payload.paths) : .moveWithinMachine(payload.paths)
            }
            return .transferBetweenMachines(from: payload.machineID, paths: payload.paths)
        }
        guard !fileURLPaths.isEmpty else { return nil }
        return .uploadLocalFiles(fileURLPaths)
    }

    public static func isDropAllowed(paths: [String], destination: String) -> Bool {
        for path in paths {
            if path == destination { return false }
            if destination.hasPrefix(path + "/") { return false }
            if (path as NSString).deletingLastPathComponent == destination { return false }
        }
        return true
    }
}

public enum NameConflictResolution: String, Equatable, Sendable {
    case replace
    case keepBoth
    case skip
}

public enum NameConflicts {
    public static func conflicting(names: [String], existing: [RemoteFileEntry]) -> [String] {
        let taken = Set(existing.map(\.name))
        return names.filter { taken.contains($0) }
    }

    public static func uniqueName(for name: String, existing: [RemoteFileEntry]) -> String {
        let taken = Set(existing.map(\.name))
        guard taken.contains(name) else { return name }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        var index = 2
        var candidate = "\(base) \(index)\(suffix)"
        while taken.contains(candidate) {
            index += 1
            candidate = "\(base) \(index)\(suffix)"
        }
        return candidate
    }

    public static func command(
        intent: DropIntent, destination: String, resolutions: [String: NameConflictResolution],
        existing: [RemoteFileEntry]
    ) -> String? {
        var parts: [String] = []
        for path in intent.paths {
            let name = (path as NSString).lastPathComponent
            let resolution = resolutions[name] ?? .replace
            guard resolution != .skip else { continue }
            let targetName =
                resolution == .keepBoth ? uniqueName(for: name, existing: existing) : name
            let target = FileListing.join(parent: destination, name: targetName)
            switch intent {
            case .moveWithinMachine:
                parts.append(
                    "mv -f \(ShellQuote.quote(path)) \(ShellQuote.quote(target))")
            case .copyWithinMachine:
                parts.append(
                    "cp -a \(ShellQuote.quote(path)) \(ShellQuote.quote(target))")
            case .transferBetweenMachines, .uploadLocalFiles:
                return nil
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " && ")
    }
}

public struct FileOperationProgress: Equatable, Sendable {
    public var title: String
    public var completed: Int
    public var total: Int
    public var bytesTransferred: Int64

    public init(title: String, completed: Int = 0, total: Int = 1, bytesTransferred: Int64 = 0) {
        self.title = title
        self.completed = completed
        self.total = total
        self.bytesTransferred = bytesTransferred
    }

    public var fraction: Double {
        total > 0 ? min(1, Double(completed) / Double(total)) : 0
    }

    public var description: String {
        guard total > 1 else { return title }
        return "\(title) (\(completed) of \(total))"
    }
}

public enum BatchRename {
    public static func apply(
        names: [String], find: String, replace: String, numbering: Bool, startAt: Int = 1
    ) -> [String] {
        var results: [String] = []
        var index = startAt
        for name in names {
            var next = name
            if !find.isEmpty {
                next = next.replacingOccurrences(of: find, with: replace)
            }
            if numbering {
                let base = (next as NSString).deletingPathExtension
                let ext = (next as NSString).pathExtension
                let suffix = ext.isEmpty ? "" : ".\(ext)"
                next = "\(base) \(index)\(suffix)"
                index += 1
            }
            results.append(next)
        }
        return results
    }
}
