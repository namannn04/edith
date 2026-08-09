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
    public let chunks: Int
    public let pendingEpisodes: Int
    public let latestIngestedAt: String?

    public init(
        sources: Int, episodes: Int, claims: Int, observations: Int,
        chunks: Int, pendingEpisodes: Int, latestIngestedAt: String?
    ) {
        self.sources = sources
        self.episodes = episodes
        self.claims = claims
        self.observations = observations
        self.chunks = chunks
        self.pendingEpisodes = pendingEpisodes
        self.latestIngestedAt = latestIngestedAt
    }

    enum CodingKeys: String, CodingKey {
        case sources
        case episodes
        case claims
        case observations
        case chunks
        case pendingEpisodes = "pending_episodes"
        case latestIngestedAt = "latest_ingested_at"
    }
}

public struct CompanionSearchHit: Codable, Equatable, Sendable {
    public let chunkId: String
    public let episodeId: String
    public let ord: Int
    public let title: String
    public let occurredAt: String
    public let kind: String
    public let snippet: String
    public let score: Double

    public init(
        chunkId: String, episodeId: String, ord: Int, title: String, occurredAt: String,
        kind: String, snippet: String, score: Double
    ) {
        self.chunkId = chunkId
        self.episodeId = episodeId
        self.ord = ord
        self.title = title
        self.occurredAt = occurredAt
        self.kind = kind
        self.snippet = snippet
        self.score = score
    }
}

public struct CompanionIndexOutcome: Codable, Equatable, Sendable {
    public let episodesIndexed: Int
    public let chunksCreated: Int

    public init(episodesIndexed: Int, chunksCreated: Int) {
        self.episodesIndexed = episodesIndexed
        self.chunksCreated = chunksCreated
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

public struct CompanionSyncOutcome: Codable, Equatable, Sendable {
    public let eventsFetched: Int
    public let observationsInserted: Int

    public init(eventsFetched: Int, observationsInserted: Int) {
        self.eventsFetched = eventsFetched
        self.observationsInserted = observationsInserted
    }
}

public struct CompanionObservation: Codable, Equatable, Sendable {
    public let id: String
    public let source: String
    public let observedAt: String
    public let kind: String
    public let summary: String

    public init(id: String, source: String, observedAt: String, kind: String, summary: String) {
        self.id = id
        self.source = source
        self.observedAt = observedAt
        self.kind = kind
        self.summary = summary
    }
}

public struct CompanionAskCitation: Codable, Equatable, Sendable {
    public let episodeId: String
    public let quote: String
    public let title: String
    public let occurredAt: String

    public init(episodeId: String, quote: String, title: String, occurredAt: String) {
        self.episodeId = episodeId
        self.quote = quote
        self.title = title
        self.occurredAt = occurredAt
    }
}

public struct CompanionAskOutcome: Codable, Equatable, Sendable {
    public let answer: String
    public let citations: [CompanionAskCitation]
    public let chunksConsidered: Int
    public let model: String

    public init(
        answer: String, citations: [CompanionAskCitation], chunksConsidered: Int, model: String
    ) {
        self.answer = answer
        self.citations = citations
        self.chunksConsidered = chunksConsidered
        self.model = model
    }
}

public struct CompanionReflectOutcome: Codable, Equatable, Sendable {
    public let episodesConsidered: Int
    public let beliefsFormed: Int
    public let model: String

    public init(episodesConsidered: Int, beliefsFormed: Int, model: String) {
        self.episodesConsidered = episodesConsidered
        self.beliefsFormed = beliefsFormed
        self.model = model
    }
}

public struct CompanionBelief: Codable, Equatable, Sendable {
    public let id: String
    public let statement: String
    public let kind: String
    public let confidence: Double
    public let firstFormed: String
    public let evidenceEpisodeIds: [String]
    public let status: String

    public init(
        id: String, statement: String, kind: String, confidence: Double, firstFormed: String,
        evidenceEpisodeIds: [String], status: String
    ) {
        self.id = id
        self.statement = statement
        self.kind = kind
        self.confidence = confidence
        self.firstFormed = firstFormed
        self.evidenceEpisodeIds = evidenceEpisodeIds
        self.status = status
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
        let value =
            override
            ?? ProcessInfo.processInfo.environment["EDITH_COMPANION_URL"]
            ?? SharedDefaults.store.string(forKey: "companionEndpoint")
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

    public func search(query: String, k: Int) async throws -> [CompanionSearchHit] {
        var components = URLComponents(url: url(for: "search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query), URLQueryItem(name: "k", value: String(k)),
        ]
        return try await request(URLRequest(url: components?.url ?? url(for: "search")))
    }

    public func index() async throws -> CompanionIndexOutcome {
        var request = URLRequest(url: url(for: "index"))
        request.httpMethod = "POST"
        request.httpBody = Data()
        return try await self.request(request)
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

    public func ask(question: String) async throws -> CompanionAskOutcome {
        var request = URLRequest(url: url(for: "ask"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(AskRequest(question: question))
        } catch {
            throw CompanionClientError.unreachable(error.localizedDescription)
        }
        return try await self.request(request, timeout: 600)
    }

    public func reflect() async throws -> CompanionReflectOutcome {
        var request = URLRequest(url: url(for: "reflect"))
        request.httpMethod = "POST"
        request.httpBody = Data()
        return try await self.request(request, timeout: 600)
    }

    public func beliefs(limit: Int) async throws -> [CompanionBelief] {
        var components = URLComponents(url: url(for: "beliefs"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        return try await request(URLRequest(url: components?.url ?? url(for: "beliefs")))
    }

    public func syncGithub() async throws -> CompanionSyncOutcome {
        var request = URLRequest(url: url(for: "connectors/github/sync"))
        request.httpMethod = "POST"
        request.httpBody = Data()
        return try await self.request(request, timeout: 120)
    }

    public func observations(limit: Int, kind: String?) async throws -> [CompanionObservation] {
        var components = URLComponents(
            url: url(for: "observations"), resolvingAgainstBaseURL: false)
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let kind, !kind.isEmpty {
            items.append(URLQueryItem(name: "kind", value: kind))
        }
        components?.queryItems = items
        return try await request(URLRequest(url: components?.url ?? url(for: "observations")))
    }

    public func ingestAudio(name: String, data: Data, mtime: String?) async throws
        -> CompanionIngestOutcome
    {
        var request = URLRequest(url: url(for: "ingest/audio"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(
                AudioIngestRequest(name: name, dataB64: data.base64EncodedString(), mtime: mtime))
        } catch {
            throw CompanionClientError.unreachable(error.localizedDescription)
        }
        return try await self.request(request, timeout: 600)
    }

    private func get<T: Decodable>(_ path: String, allowing: Set<Int> = []) async throws -> T {
        try await request(URLRequest(url: url(for: path)), allowing: allowing)
    }

    private func request<T: Decodable>(
        _ request: URLRequest, allowing: Set<Int> = [], timeout: TimeInterval = 5
    ) async throws
        -> T
    {
        var request = request
        request.timeoutInterval = timeout
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

private struct AudioIngestRequest: Encodable {
    let name: String
    let dataB64: String
    let mtime: String?
}

private struct AskRequest: Encodable {
    let question: String
}
