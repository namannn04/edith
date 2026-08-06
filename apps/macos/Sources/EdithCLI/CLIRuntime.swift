import Foundation

public struct CLIFailure: Error, CustomStringConvertible, Equatable {
    public enum Kind: Int32, Equatable, Sendable {
        case failure = 1
        case notFound = 3
        case unavailable = 4
    }

    public let kind: Kind
    public let message: String
    public let hint: String?

    public init(_ kind: Kind, _ message: String, hint: String? = nil) {
        self.kind = kind
        self.message = message
        self.hint = hint
    }

    public init(_ message: String, hint: String? = nil) {
        self.init(.failure, message, hint: hint)
    }

    public var description: String { message }

    public static func notFound(_ message: String, hint: String? = nil) -> CLIFailure {
        CLIFailure(.notFound, message, hint: hint)
    }

    public static func unavailable(_ message: String, hint: String? = nil) -> CLIFailure {
        CLIFailure(.unavailable, message, hint: hint)
    }
}

public enum CLIOut {
    nonisolated(unsafe) private static var stdoutHandle = FileHandle.standardOutput
    nonisolated(unsafe) private static var stderrHandle = FileHandle.standardError

    public static func out(_ text: String) {
        guard let data = (text + "\n").data(using: .utf8) else { return }
        stdoutHandle.write(data)
    }

    public static func raw(_ text: String) {
        guard !text.isEmpty, let data = text.data(using: .utf8) else { return }
        stdoutHandle.write(data)
    }

    public static func note(_ text: String) {
        guard let data = (text + "\n").data(using: .utf8) else { return }
        stderrHandle.write(data)
    }

    public static func rawError(_ text: String) {
        guard !text.isEmpty, let data = text.data(using: .utf8) else { return }
        stderrHandle.write(data)
    }

    public static func json(_ value: JSONValue) {
        out(JSONSerializer.string(value))
    }

    public static func report(_ failure: CLIFailure) {
        note("error: " + failure.message)
        if let hint = failure.hint { note("hint: " + hint) }
    }
}

public enum TextTable {
    public static func render(headers: [String], rows: [[String]]) -> String {
        guard !rows.isEmpty else { return headers.joined(separator: "  ") }
        var widths = headers.map { $0.count }
        for row in rows {
            for (index, cell) in row.enumerated() where index < widths.count {
                widths[index] = max(widths[index], cell.count)
            }
        }
        var lines: [String] = [line(headers, widths)]
        for row in rows { lines.append(line(row, widths)) }
        return lines.joined(separator: "\n")
    }

    private static func line(_ cells: [String], _ widths: [Int]) -> String {
        var parts: [String] = []
        for (index, width) in widths.enumerated() {
            let cell = index < cells.count ? cells[index] : ""
            parts.append(
                index == widths.count - 1
                    ? cell : cell.padding(toLength: width, withPad: " ", startingAt: 0))
        }
        return parts.joined(separator: "  ").trimmingTrailingSpaces()
    }
}

extension String {
    func trimmingTrailingSpaces() -> String {
        var text = self
        while text.hasSuffix(" ") { text.removeLast() }
        return text
    }
}
