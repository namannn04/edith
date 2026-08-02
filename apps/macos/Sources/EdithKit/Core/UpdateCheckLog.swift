import Foundation

public struct UpdateCheckRecord: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case automatic
        case manual

        public var label: String {
            switch self {
            case .automatic: return "Automatic"
            case .manual: return "Manual"
            }
        }
    }

    public enum Outcome: String, Codable, Sendable {
        case upToDate
        case updateFound
        case failed
    }

    public let id: UUID
    public let date: Date
    public let kind: Kind
    public let outcome: Outcome
    public let version: String?
    public let detail: String?

    public init(
        id: UUID = UUID(), date: Date, kind: Kind, outcome: Outcome, version: String? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.outcome = outcome
        self.version = version
        self.detail = detail
    }

    public var summary: String {
        switch outcome {
        case .upToDate: return "Up to date"
        case .updateFound: return version.map { "Found \($0)" } ?? "Update found"
        case .failed: return detail?.isEmpty == false ? detail! : "Check failed"
        }
    }
}

public enum UpdateCheckLog {
    public static let limit = 200

    public static var url: URL { AppData.supportDir.appendingPathComponent("update-checks.json") }

    public static func load(from url: URL = UpdateCheckLog.url) -> [UpdateCheckRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let records = try? decoder.decode([UpdateCheckRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.date > $1.date }
    }

    @discardableResult
    public static func append(
        _ record: UpdateCheckRecord, to url: URL = UpdateCheckLog.url
    ) -> [UpdateCheckRecord] {
        let records = Array(([record] + load(from: url)).prefix(limit))
        save(records, to: url)
        return records
    }

    public static func clear(at url: URL = UpdateCheckLog.url) {
        try? FileManager.default.removeItem(at: url)
    }

    public static func count(of kind: UpdateCheckRecord.Kind, in records: [UpdateCheckRecord])
        -> Int
    {
        records.filter { $0.kind == kind }.count
    }

    static func save(_ records: [UpdateCheckRecord], to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

public struct UpdateCheckInterval: Identifiable, Equatable, Sendable {
    public let seconds: TimeInterval
    public let label: String

    public var id: TimeInterval { seconds }

    public init(seconds: TimeInterval, label: String) {
        self.seconds = seconds
        self.label = label
    }

    public static let choices: [UpdateCheckInterval] = [
        UpdateCheckInterval(seconds: 3_600, label: "Every hour"),
        UpdateCheckInterval(seconds: 21_600, label: "Every 6 hours"),
        UpdateCheckInterval(seconds: 43_200, label: "Every 12 hours"),
        UpdateCheckInterval(seconds: 86_400, label: "Every day"),
        UpdateCheckInterval(seconds: 604_800, label: "Every week"),
    ]

    public static let fallback = UpdateCheckInterval(seconds: 86_400, label: "Every day")

    public static func nearest(to seconds: TimeInterval) -> UpdateCheckInterval {
        choices.min { abs($0.seconds - seconds) < abs($1.seconds - seconds) } ?? fallback
    }
}
