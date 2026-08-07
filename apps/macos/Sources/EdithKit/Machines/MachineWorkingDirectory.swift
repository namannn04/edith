import Foundation

public enum MachineWorkingDirectory {
    public static let sharedSessionKey = "shared"

    public static var root: URL { MachinePaths.dir.appendingPathComponent("cwd") }

    public static func sessionKey(descriptor: Int32 = STDIN_FILENO) -> String {
        guard isatty(descriptor) == 1, let name = ttyname(descriptor) else {
            return sharedSessionKey
        }
        return sanitize(String(cString: name))
    }

    public static func sanitize(_ tty: String) -> String {
        let stripped = tty.hasPrefix("/dev/") ? String(tty.dropFirst(5)) : tty
        let cleaned = stripped.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let key = String(cleaned)
        return key.isEmpty ? sharedSessionKey : key
    }

    public static func file(for machineID: UUID, session: String) -> URL {
        let hash = machineID.uuidString.replacingOccurrences(of: "-", with: "").prefix(10)
        return root.appendingPathComponent(String(hash)).appendingPathComponent(session)
    }

    public static func load(
        machineID: UUID, session: String = sessionKey(), fileManager: FileManager = .default
    ) -> String? {
        let path = file(for: machineID, session: session)
        guard let data = fileManager.contents(atPath: path.path) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    public static func save(
        _ directory: String, machineID: UUID, session: String = sessionKey(),
        fileManager: FileManager = .default
    ) {
        let trimmed = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return clear(machineID: machineID, session: session) }
        let path = file(for: machineID, session: session)
        try? fileManager.createDirectory(
            at: path.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try? Data(trimmed.utf8).write(to: path, options: .atomic)
    }

    public static func clear(
        machineID: UUID, session: String = sessionKey(), fileManager: FileManager = .default
    ) {
        try? fileManager.removeItem(at: file(for: machineID, session: session))
    }

    public static func prefixed(_ command: String, directory: String?) -> String {
        guard let directory, !directory.isEmpty else { return command }
        return "cd " + ShellQuote.quote(directory) + " 2>/dev/null || cd; " + command
    }

    public static func resolveCommand(target: String?, from directory: String?) -> String {
        let base = directory.map { "cd " + ShellQuote.quote($0) + " 2>/dev/null; " } ?? ""
        guard let target, !target.isEmpty else { return base + "cd && pwd" }
        return base + "cd -- " + ShellQuote.quote(target) + " && pwd"
    }

    public static func isChangeDirectory(_ words: [String]) -> Bool {
        words.first == "cd" && words.count <= 2
    }
}
