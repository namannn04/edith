import Foundation

public struct CompanionHealth: Codable, Equatable, Sendable {
    public let ok: Bool
    public let checks: [CompanionCheck]

    public init(ok: Bool, checks: [CompanionCheck]) {
        self.ok = ok
        self.checks = checks
    }
}

public struct CompanionCheck: Codable, Equatable, Sendable {
    public let name: String
    public let ok: Bool
    public let detail: String

    public init(name: String, ok: Bool, detail: String) {
        self.name = name
        self.ok = ok
        self.detail = detail
    }
}

public struct CompanionStatus: Codable, Equatable, Sendable {
    public let sources: Int
    public let episodes: Int
    public let claims: Int
    public let observations: Int
    public let latestIngestedAt: String?

    public init(
        sources: Int, episodes: Int, claims: Int, observations: Int,
        latestIngestedAt: String?
    ) {
        self.sources = sources
        self.episodes = episodes
        self.claims = claims
        self.observations = observations
        self.latestIngestedAt = latestIngestedAt
    }

    enum CodingKeys: String, CodingKey {
        case sources
        case episodes
        case claims
        case observations
        case latestIngestedAt = "latest_ingested_at"
    }
}

public struct CompanionEpisode: Codable, Equatable, Sendable {
    public let id: String
    public let occurredAt: String
    public let kind: String
    public let title: String
    public let sha256: String

    public init(id: String, occurredAt: String, kind: String, title: String, sha256: String) {
        self.id = id
        self.occurredAt = occurredAt
        self.kind = kind
        self.title = title
        self.sha256 = sha256
    }

    enum CodingKeys: String, CodingKey {
        case id
        case occurredAt = "occurred_at"
        case kind
        case title
        case sha256
    }
}

public struct CompanionIngestFile: Codable, Equatable, Sendable {
    public let name: String
    public let text: String
    public let mtime: String?

    public init(name: String, text: String, mtime: String? = nil) {
        self.name = name
        self.text = text
        self.mtime = mtime
    }
}

public struct CompanionIngestOutcome: Codable, Equatable, Sendable {
    public let name: String
    public let status: String
    public let episodeId: String
    public let occurredAt: String

    public init(name: String, status: String, episodeId: String, occurredAt: String) {
        self.name = name
        self.status = status
        self.episodeId = episodeId
        self.occurredAt = occurredAt
    }
}

public enum CompanionClientError: Error, Equatable, LocalizedError, Sendable {
    case unreachable(String)
    case badResponse(Int, String)

    public var errorDescription: String? {
        switch self {
        case let .unreachable(detail):
            return detail
        case let .badResponse(status, detail):
            return detail.isEmpty ? "HTTP \(status)" : "HTTP \(status): \(detail)"
        }
    }
}

public struct CompanionClient: Sendable {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public static func endpoint(override: String?) -> URL {
        let fallback = URL(string: "http://127.0.0.1:4820")!
        let value = override ?? ProcessInfo.processInfo.environment["EDITH_COMPANION_URL"]
        guard let value, !value.isEmpty else { return fallback }
        return URL(string: value) ?? fallback
    }

    public func health() async throws -> CompanionHealth {
        try await get("health", allowing: [503])
    }

    public func status() async throws -> CompanionStatus {
        try await get("status")
    }

    public func episodes(limit: Int) async throws -> [CompanionEpisode] {
        var components = URLComponents(url: url(for: "episodes"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        return try await request(URLRequest(url: components?.url ?? url(for: "episodes")))
    }

    public func ingest(files: [CompanionIngestFile]) async throws -> [CompanionIngestOutcome] {
        var request = URLRequest(url: url(for: "ingest"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(IngestRequest(files: files))
        } catch {
            throw CompanionClientError.unreachable(error.localizedDescription)
        }
        return try await self.request(request)
    }

    private func get<T: Decodable>(_ path: String, allowing: Set<Int> = []) async throws -> T {
        try await request(URLRequest(url: url(for: path)), allowing: allowing)
    }

    private func request<T: Decodable>(_ request: URLRequest, allowing: Set<Int> = []) async throws
        -> T
    {
        var request = request
        request.timeoutInterval = 5
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CompanionClientError.unreachable(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw CompanionClientError.unreachable("the server returned no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) || allowing.contains(http.statusCode) else {
            throw CompanionClientError.badResponse(http.statusCode, responseText(data))
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CompanionClientError.badResponse(http.statusCode, error.localizedDescription)
        }
    }

    private func url(for path: String) -> URL {
        baseURL.appendingPathComponent("v1").appendingPathComponent(path)
    }

    private func responseText(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct IngestRequest: Encodable {
    let files: [CompanionIngestFile]
}
