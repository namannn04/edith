import ArgumentParser
import EdithKit
import Foundation

struct CompanionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "companion",
        abstract: "The companion memory backend.",
        discussion: """
            The backend runs with docker compose from apps/companion. Pass --endpoint or
            set EDITH_COMPANION_URL to point at it; the default is http://127.0.0.1:4820.

            For a remote backend, run `ed machines forwards on tuf 2`, then
            `ed companion status`.
            """,
        subcommands: [
            CompanionStatusCommand.self, CompanionDoctorCommand.self,
            CompanionSearchCommand.self, CompanionIndexCommand.self,
            CompanionIngestCommand.self, CompanionEpisodesCommand.self,
            CompanionSyncCommand.self, CompanionObservationsCommand.self,
            CompanionReflectCommand.self, CompanionBeliefsCommand.self,
            CompanionAskCommand.self,
        ],
        defaultSubcommand: CompanionStatusCommand.self)
}

struct CompanionAskCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ask", abstract: "Ask a question answered from your own memory.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    @Argument(help: "The question to answer.")
    var question: String

    func run() async throws {
        try await execute {
            let outcome = try await CompanionBridge.request(endpoint: endpoint) { client in
                try await client.ask(question: question)
            }
            guard !json else {
                CLIOut.json(
                    .object([
                        "answer": .string(outcome.answer),
                        "citations": .array(
                            outcome.citations.map { citation in
                                .object([
                                    "episodeId": .string(citation.episodeId),
                                    "quote": .string(citation.quote),
                                    "title": .string(citation.title),
                                    "occurredAt": .string(citation.occurredAt),
                                ])
                            }),
                        "chunksConsidered": .int(outcome.chunksConsidered),
                        "model": .string(outcome.model),
                    ]))
                return
            }
            CLIOut.out(outcome.answer)
            for (index, citation) in outcome.citations.enumerated() {
                CLIOut.out("[\(index + 1)] \(citation.title) (\(citation.occurredAt))")
                if !citation.quote.isEmpty {
                    CLIOut.out("    \u{201C}\(citation.quote)\u{201D}")
                }
            }
        }
    }
}

struct CompanionReflectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reflect", abstract: "Distill fresh beliefs from recent episodes.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    func run() async throws {
        try await execute {
            let outcome = try await CompanionBridge.request(endpoint: endpoint) { client in
                try await client.reflect()
            }
            guard !json else {
                CLIOut.json(
                    .object([
                        "episodesConsidered": .int(outcome.episodesConsidered),
                        "beliefsFormed": .int(outcome.beliefsFormed),
                        "model": .string(outcome.model),
                    ]))
                return
            }
            CLIOut.out(
                "considered \(outcome.episodesConsidered) episodes, "
                    + "formed \(outcome.beliefsFormed) beliefs (\(outcome.model))")
        }
    }
}

struct CompanionBeliefsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "beliefs", abstract: "List what the companion believes about you.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    @Option(name: .long, help: "How many to list.")
    var limit = 20

    func run() async throws {
        try await execute {
            let limit = try ArgumentChecks.positive(self.limit, "--limit")
            let beliefs = try await CompanionBridge.request(endpoint: endpoint) { client in
                try await client.beliefs(limit: limit)
            }
            guard !json else {
                CLIOut.json(
                    .array(
                        beliefs.map { belief in
                            .object([
                                "id": .string(belief.id),
                                "statement": .string(belief.statement),
                                "kind": .string(belief.kind),
                                "confidence": .double(belief.confidence),
                                "firstFormed": .string(belief.firstFormed),
                                "evidenceEpisodeIds": .strings(belief.evidenceEpisodeIds),
                                "status": .string(belief.status),
                            ])
                        }))
                return
            }
            guard !beliefs.isEmpty else {
                CLIOut.out("no beliefs yet, run `ed companion reflect`")
                return
            }
            for (index, belief) in beliefs.enumerated() {
                CLIOut.out(
                    "\(index + 1). [\(belief.kind), \(Int(belief.confidence * 100))%] "
                        + belief.statement)
                CLIOut.out(
                    "   evidence: \(belief.evidenceEpisodeIds.count) episodes, "
                        + "since \(belief.firstFormed)")
            }
        }
    }
}

struct CompanionSyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync", abstract: "Pull a connector's activity into observations.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    @Argument(help: "Connector to sync; only github exists so far.")
    var connector: String

    func run() async throws {
        try await execute {
            guard connector == "github" else {
                throw CLIFailure.usage(
                    "unknown connector \(connector)", hint: "the only connector so far is github")
            }
            let outcome = try await CompanionBridge.request(endpoint: endpoint) { client in
                try await client.syncGithub()
            }
            guard !json else {
                CLIOut.json(
                    .object([
                        "eventsFetched": .int(outcome.eventsFetched),
                        "observationsInserted": .int(outcome.observationsInserted),
                    ]))
                return
            }
            CLIOut.out(
                "fetched \(outcome.eventsFetched) events, "
                    + "\(outcome.observationsInserted) new observations")
        }
    }
}

struct CompanionObservationsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "observations", abstract: "List what the connectors saw you do.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    @Option(name: .long, help: "How many to list.")
    var limit = 20

    @Option(name: .long, help: "Only this observation kind.")
    var kind: String?

    func run() async throws {
        try await execute {
            let limit = try ArgumentChecks.positive(self.limit, "--limit")
            let observations = try await CompanionBridge.request(endpoint: endpoint) { client in
                try await client.observations(limit: limit, kind: kind)
            }
            guard !json else {
                CLIOut.json(
                    .array(
                        observations.map { observation in
                            .object([
                                "id": .string(observation.id),
                                "source": .string(observation.source),
                                "observedAt": .string(observation.observedAt),
                                "kind": .string(observation.kind),
                                "summary": .string(observation.summary),
                            ])
                        }))
                return
            }
            guard !observations.isEmpty else {
                CLIOut.out("no observations yet")
                return
            }
            let rows = observations.enumerated().map { index, observation in
                [
                    String(index + 1), observation.kind, observation.summary,
                    observation.observedAt,
                ]
            }
            CLIOut.raw(TextTable.render(headers: ["#", "KIND", "SUMMARY", "OBSERVED"], rows: rows))
        }
    }
}

enum CompanionBridge {
    static func request<T>(
        endpoint: String?, operation: (CompanionClient) async throws -> T
    ) async throws -> T {
        let resolved = CompanionClient.endpoint(override: endpoint)
        do {
            return try await operation(CompanionClient(baseURL: resolved))
        } catch let error as CompanionClientError {
            throw CLIFailure.unavailable(
                "the companion backend at \(resolved.absoluteString) is unavailable",
                hint: "\(error.localizedDescription); run `docker compose up` in "
                    + "apps/companion or `ed machines forwards on tuf 2`")
        }
    }

    static func embeddingRequest<T>(
        endpoint: String?, operation: (CompanionClient) async throws -> T
    ) async throws -> T {
        let resolved = CompanionClient.endpoint(override: endpoint)
        do {
            return try await operation(CompanionClient(baseURL: resolved))
        } catch let CompanionClientError.badResponse(status, detail) where status == 502 {
            throw CLIFailure.unavailable(
                "the Ollama embedding service is unavailable",
                hint: detail.isEmpty ? "check the Ollama service and embedding model" : detail)
        } catch let error as CompanionClientError {
            throw CLIFailure.unavailable(
                "the companion backend at \(resolved.absoluteString) is unavailable",
                hint: "\(error.localizedDescription); run `docker compose up` in "
                    + "apps/companion or `ed machines forwards on tuf 2`")
        }
    }

    static func statusJSON(_ status: CompanionStatus) -> JSONValue {
        .object([
            "sources": .int(status.sources),
            "episodes": .int(status.episodes),
            "claims": .int(status.claims),
            "observations": .int(status.observations),
            "chunks": .int(status.chunks),
            "pendingEpisodes": .int(status.pendingEpisodes),
            "latestIngestedAt": .optional(status.latestIngestedAt),
        ])
    }

    static func searchJSON(_ hit: CompanionSearchHit) -> JSONValue {
        .object([
            "chunkId": .string(hit.chunkId),
            "episodeId": .string(hit.episodeId),
            "ord": .int(hit.ord),
            "title": .string(hit.title),
            "occurredAt": .string(hit.occurredAt),
            "kind": .string(hit.kind),
            "snippet": .string(hit.snippet),
            "score": .double(hit.score),
        ])
    }

    static func indexJSON(_ outcome: CompanionIndexOutcome) -> JSONValue {
        .object([
            "episodesIndexed": .int(outcome.episodesIndexed),
            "chunksCreated": .int(outcome.chunksCreated),
        ])
    }

    static func outcomeJSON(_ outcome: CompanionIngestOutcome) -> JSONValue {
        .object([
            "name": .string(outcome.name),
            "status": .string(outcome.status),
            "episodeId": .string(outcome.episodeId),
            "occurredAt": .string(outcome.occurredAt),
        ])
    }

    static func episodeJSON(_ episode: CompanionEpisode) -> JSONValue {
        .object([
            "id": .string(episode.id),
            "occurredAt": .string(episode.occurredAt),
            "kind": .string(episode.kind),
            "title": .string(episode.title),
            "sha256": .string(episode.sha256),
        ])
    }
}

struct CompanionStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status", abstract: "Count what the companion remembers.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    func run() async throws {
        try await execute {
            let status = try await CompanionBridge.request(endpoint: endpoint) { client in
                try await client.status()
            }
            guard !json else {
                CLIOut.json(CompanionBridge.statusJSON(status))
                return
            }
            CLIOut.out(
                TextTable.render(
                    headers: ["RESOURCE", "COUNT"],
                    rows: [
                        ["sources", String(status.sources)],
                        ["episodes", String(status.episodes)],
                        ["claims", String(status.claims)],
                        ["observations", String(status.observations)],
                        ["chunks", String(status.chunks)],
                        ["pending episodes", String(status.pendingEpisodes)],
                    ]))
            if let latest = status.latestIngestedAt { CLIOut.out("latest  \(latest)") }
        }
    }
}

struct CompanionSearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search", abstract: "Search companion memory with hybrid retrieval.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    @Option(name: .long, help: "How many hits.")
    var limit = 8

    @Argument(help: "What to look for.")
    var query: String

    func run() async throws {
        try await execute {
            let limit = try ArgumentChecks.positive(self.limit, "--limit")
            guard limit <= 50 else {
                throw CLIFailure.usage("--limit must be 50 or less")
            }
            let hits = try await CompanionBridge.embeddingRequest(endpoint: endpoint) { client in
                try await client.search(query: query, k: limit)
            }
            guard !json else {
                CLIOut.json(.array(hits.map(CompanionBridge.searchJSON)))
                return
            }
            guard !hits.isEmpty else {
                CLIOut.out("no matches")
                return
            }
            let rows = hits.enumerated().map { offset, hit in
                [
                    String(offset + 1), String(format: "%.6f", hit.score), hit.title,
                    hit.occurredAt,
                ]
            }
            CLIOut.out(
                TextTable.render(headers: ["#", "SCORE", "TITLE", "OCCURRED"], rows: rows))
            for (offset, hit) in hits.enumerated() {
                CLIOut.out("  \(offset + 1)  \(TextTable.oneLine(hit.snippet))")
            }
        }
    }
}

struct CompanionIndexCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "index", abstract: "Embed pending companion episodes.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    func run() async throws {
        try await execute {
            let outcome = try await CompanionBridge.embeddingRequest(endpoint: endpoint) { client in
                try await client.index()
            }
            guard !json else {
                CLIOut.json(CompanionBridge.indexJSON(outcome))
                return
            }
            CLIOut.out(
                "indexed \(outcome.episodesIndexed) episodes into \(outcome.chunksCreated) chunks")
        }
    }
}

struct CompanionDoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor", abstract: "Check the companion's dependencies.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    func run() async throws {
        try await execute {
            let health = try await CompanionBridge.request(endpoint: endpoint) { client in
                try await client.health()
            }
            guard !json else {
                CLIOut.json(
                    .object([
                        "ok": .bool(health.ok),
                        "checks": .array(
                            health.checks.map { check in
                                .object([
                                    "name": .string(check.name),
                                    "ok": .bool(check.ok),
                                    "detail": .string(check.detail),
                                ])
                            }),
                    ]))
                return
            }
            for check in health.checks {
                let state = check.ok ? "ok" : "fail"
                CLIOut.out("\(check.name)  \(state)  \(TextTable.oneLine(check.detail))")
            }
        }
    }
}

struct CompanionIngestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ingest", abstract: "Ingest Markdown notes and voice recordings as episodes.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    @Argument(help: "Markdown or audio file, or a folder of them.", completion: .file())
    var path: String

    func run() async throws {
        try await execute {
            let url = URL(fileURLWithPath: path.expandingTilde())
            let scan: CompanionScanResult
            let audioScan: CompanionAudioScanResult
            do {
                scan = try CompanionScan.markdownFiles(at: url)
                audioScan = try CompanionScan.audioFiles(at: url)
            } catch {
                throw CLIFailure.usage(
                    "could not scan \(url.path)", hint: error.localizedDescription)
            }
            for name in scan.skipped {
                CLIOut.note("skipped \(name): larger than 2MB")
            }
            for name in audioScan.skipped {
                CLIOut.note("skipped \(name): larger than 48MB")
            }
            guard !scan.files.isEmpty || !audioScan.files.isEmpty else {
                throw CLIFailure.usage(
                    "no Markdown or audio files found at \(url.path)",
                    hint: "pass a .md or audio file, or a folder containing them")
            }
            var outcomes: [CompanionIngestOutcome] = []
            for start in stride(from: 0, to: scan.files.count, by: 200) {
                let end = min(start + 200, scan.files.count)
                let batch = Array(scan.files[start..<end])
                let added = try await CompanionBridge.request(endpoint: endpoint) { client in
                    try await client.ingest(files: batch)
                }
                outcomes.append(contentsOf: added)
            }
            for file in audioScan.files {
                let outcome = try await CompanionBridge.request(endpoint: endpoint) { client in
                    try await client.ingestAudio(
                        name: file.name, data: file.data, mtime: file.mtime)
                }
                outcomes.append(outcome)
            }
            let skippedCount = scan.skipped.count + audioScan.skipped.count
            let ingested = outcomes.filter { $0.status == "ingested" }.count
            let duplicates = outcomes.filter { $0.status == "duplicate" }.count
            guard !json else {
                CLIOut.json(
                    .object([
                        "ingested": .int(ingested),
                        "duplicates": .int(duplicates),
                        "skipped": .int(skippedCount),
                        "results": .array(outcomes.map(CompanionBridge.outcomeJSON)),
                    ]))
                return
            }
            for outcome in outcomes {
                CLIOut.out("\(outcome.status)  \(outcome.name)")
            }
            CLIOut.out(
                "\(ingested) ingested, \(duplicates) duplicates, \(skippedCount) skipped")
        }
    }
}

struct CompanionEpisodesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "episodes", abstract: "List recent companion episodes.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    @Option(name: .long, help: "How many to list.")
    var limit = 20

    func run() async throws {
        try await execute {
            let limit = try ArgumentChecks.positive(self.limit, "--limit")
            let episodes = try await CompanionBridge.request(endpoint: endpoint) { client in
                try await client.episodes(limit: limit)
            }
            guard !json else {
                CLIOut.json(.array(episodes.map(CompanionBridge.episodeJSON)))
                return
            }
            let rows = episodes.enumerated().map { offset, episode in
                [String(offset + 1), episode.title, episode.kind, episode.occurredAt]
            }
            CLIOut.out(
                TextTable.render(headers: ["#", "TITLE", "KIND", "OCCURRED"], rows: rows))
        }
    }
}
