import Foundation

public enum ArgumentRewriting {
    public static let reserved: Set<String> = Set(
        CommandTree.topLevelNames + ["__complete", "help"])

    public static func rewrite(_ arguments: [String], machines: [String]) -> [String] {
        guard let first = arguments.first, !first.hasPrefix("-") else { return arguments }
        guard !reserved.contains(first) else { return arguments }
        guard machines.contains(where: { $0.lowercased() == first.lowercased() }) else {
            return arguments
        }
        let rest = Array(arguments.dropFirst())
        guard !rest.isEmpty else { return ["machines", "show", first] }
        return ["machines", "exec", first, "--"] + rest
    }
}
