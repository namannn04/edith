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
            CompanionIngestCommand.self, CompanionEpisodesCommand.self,
        ],
        defaultSubcommand: CompanionStatusCommand.self)
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

    static func statusJSON(_ status: CompanionStatus) -> JSONValue {
        .object([
            "sources": .int(status.sources),
            "episodes": .int(status.episodes),
            "claims": .int(status.claims),
            "observations": .int(status.observations),
            "latestIngestedAt": .optional(status.latestIngestedAt),
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
                    ]))
            if let latest = status.latestIngestedAt { CLIOut.out("latest  \(latest)") }
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
        commandName: "ingest", abstract: "Ingest Markdown notes as episodes.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(name: .long, help: "Companion API base URL.")
    var endpoint: String?

    @Argument(help: "Markdown file or folder to ingest.", completion: .file())
    var path: String

    func run() async throws {
        try await execute {
            let url = URL(fileURLWithPath: path.expandingTilde())
            let scan: CompanionScanResult
            do {
                scan = try CompanionScan.markdownFiles(at: url)
            } catch {
                throw CLIFailure.usage(
                    "could not scan \(url.path)", hint: error.localizedDescription)
            }
            for name in scan.skipped {
                CLIOut.note("skipped \(name): larger than 2MB")
            }
            guard !scan.files.isEmpty else {
                throw CLIFailure.usage(
                    "no Markdown files found at \(url.path)",
                    hint: "pass a .md file or a folder containing .md files")
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
            let ingested = outcomes.filter { $0.status == "ingested" }.count
            let duplicates = outcomes.filter { $0.status == "duplicate" }.count
            guard !json else {
                CLIOut.json(
                    .object([
                        "ingested": .int(ingested),
                        "duplicates": .int(duplicates),
                        "skipped": .int(scan.skipped.count),
                        "results": .array(outcomes.map(CompanionBridge.outcomeJSON)),
                    ]))
                return
            }
            for outcome in outcomes {
                CLIOut.out("\(outcome.status)  \(outcome.name)")
            }
            CLIOut.out(
                "\(ingested) ingested, \(duplicates) duplicates, \(scan.skipped.count) skipped")
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
