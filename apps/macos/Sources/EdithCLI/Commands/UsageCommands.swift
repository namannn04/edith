import ArgumentParser
import EdithKit
import Foundation

struct UsageCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "usage",
        abstract: "Agent usage, token counts, cost and rate limits.",
        discussion: """
            Numbers come from the same files the app's dashboard reads, so the CLI and
            the UI cannot disagree. `ed usage refresh` asks the running app to collect
            fresh data.
            """,
        subcommands: [
            UsageLimitsCommand.self, UsageSummaryCommand.self, UsageDailyCommand.self,
            UsageModelsCommand.self, UsageProjectsCommand.self, UsageSourcesCommand.self,
            UsageRefreshCommand.self,
        ],
        defaultSubcommand: UsageSummaryCommand.self)
}

struct UsageWindow: ParsableArguments {
    @Option(help: "today, week, month or all.")
    var range: String = "all"

    @Option(name: .long, help: "Only this usage source. Repeat to include several.")
    var source: [String] = []

    func resolved() throws -> UsageRange {
        guard let value = UsageRange(rawValue: range.lowercased()) else {
            throw CLIFailure.notFound(
                "no range named \(range)",
                hint: "ranges: " + UsageRange.allCases.map(\.rawValue).joined(separator: ", "))
        }
        return value
    }

    var sources: Set<String>? { source.isEmpty ? nil : Set(source) }
}

struct UsageLimitsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "limits", abstract: "Session and weekly rate limits per provider.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    func run() async throws {
        try await execute {
            let providers = LimitsReport.providers()
            guard !providers.isEmpty else {
                throw CLIFailure.unavailable(
                    "no limit history yet",
                    hint: "enable the Agent Usage extension and let Edith poll once")
            }
            guard !json else {
                CLIOut.json(
                    .array(
                        providers.map {
                            LimitsReport.json(
                                provider: $0.0, observedAt: $0.1, session: $0.2, week: $0.3)
                        }))
                return
            }
            let rows = providers.map { provider, observedAt, session, week in
                [
                    provider.label,
                    session.map { String(format: "%.1f%%", $0.percent) } ?? "-",
                    week.map { String(format: "%.1f%%", $0.percent) } ?? "-",
                    session?.resetsAt.map { resetText($0) } ?? "-",
                    JSONSerializer.iso.string(from: observedAt),
                ]
            }
            CLIOut.out(
                TextTable.render(
                    headers: ["PROVIDER", "SESSION", "WEEKLY", "SESSION RESETS", "OBSERVED"],
                    rows: rows))
        }
    }

    private func resetText(_ date: Date) -> String {
        let seconds = max(0, date.timeIntervalSinceNow)
        return ByteFormatter.duration(seconds)
    }
}

struct UsageSummaryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "summary", abstract: "Cost and tokens over a window.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @OptionGroup var window: UsageWindow

    func run() async throws {
        try await execute {
            let document = try UsageDocument.load()
            let range = try window.resolved()
            let days = UsageAnalysis.days(document, range: range)
            let totals = UsageAnalysis.totals(days, sources: window.sources)
            let bySource = UsageAnalysis.bySource(days, sources: window.sources)
            guard !json else {
                CLIOut.json(
                    .object([
                        "range": .string(range.rawValue),
                        "generatedAt": .optional(document.generatedAt),
                        "days": .int(days.count),
                        "totals": totals.json,
                        "bySource": .object(bySource.mapValues { $0.json }),
                    ]))
                return
            }
            CLIOut.out(String(format: "cost    $%.2f", totals.cost))
            CLIOut.out("tokens  \(Int(totals.tokens))")
            CLIOut.out("days    \(days.count)")
            let rows = bySource.keys.sorted().map { key in
                [
                    key, String(format: "%.2f", bySource[key]?.cost ?? 0),
                    String(Int(bySource[key]?.tokens ?? 0)),
                ]
            }
            CLIOut.out("")
            CLIOut.out(TextTable.render(headers: ["SOURCE", "COST", "TOKENS"], rows: rows))
        }
    }
}

struct UsageDailyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "daily", abstract: "Per-day cost and tokens.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @OptionGroup var window: UsageWindow

    func run() async throws {
        try await execute {
            let document = try UsageDocument.load()
            let range = try window.resolved()
            let days = UsageAnalysis.byDay(
                UsageAnalysis.days(document, range: range), sources: window.sources)
            guard !json else {
                CLIOut.json(
                    .array(
                        days.map { period, totals in
                            .object(["date": .string(period), "totals": totals.json])
                        }))
                return
            }
            let rows = days.map { period, totals in
                [period, String(format: "%.2f", totals.cost), String(Int(totals.tokens))]
            }
            CLIOut.out(TextTable.render(headers: ["DATE", "COST", "TOKENS"], rows: rows))
        }
    }
}

struct UsageModelsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "models", abstract: "Cost and tokens per model.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @OptionGroup var window: UsageWindow

    func run() async throws {
        try await execute {
            let document = try UsageDocument.load()
            let range = try window.resolved()
            let models = UsageAnalysis.byModel(
                UsageAnalysis.days(document, range: range), sources: window.sources)
            let ordered = models.sorted { $0.value.cost > $1.value.cost }
            guard !json else {
                CLIOut.json(
                    .array(
                        ordered.map { name, totals in
                            .object(["model": .string(name), "totals": totals.json])
                        }))
                return
            }
            let rows = ordered.map { name, totals in
                [name, String(format: "%.2f", totals.cost), String(Int(totals.tokens))]
            }
            CLIOut.out(TextTable.render(headers: ["MODEL", "COST", "TOKENS"], rows: rows))
        }
    }
}

struct UsageProjectsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "projects", abstract: "Cost and tokens per project.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Option(help: "today, week, month or all.")
    var range: String = "all"

    @Option(help: "Show at most this many projects.")
    var limit: Int = 25

    func run() async throws {
        try await execute {
            guard let value = UsageRange(rawValue: range.lowercased()) else {
                throw CLIFailure.notFound(
                    "no range named \(range)",
                    hint: "ranges: "
                        + UsageRange.allCases.map(\.rawValue).joined(separator: ", "))
            }
            let limit = try ArgumentChecks.positive(self.limit, "--limit")
            let document = try UsageDocument.load()
            let projects = UsageAnalysis.byProject(UsageAnalysis.days(document, range: value))
                .prefix(limit)
            guard !json else {
                CLIOut.json(
                    .array(
                        projects.map { name, cost, tokens in
                            .object([
                                "project": .string(name), "cost": .double(cost),
                                "tokens": .double(tokens),
                            ])
                        }))
                return
            }
            let rows = projects.map { name, cost, tokens in
                [name, String(format: "%.2f", cost), String(Int(tokens))]
            }
            CLIOut.out(TextTable.render(headers: ["PROJECT", "COST", "TOKENS"], rows: rows))
        }
    }
}

struct UsageSourcesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sources", abstract: "The agents that produced the usage history.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    func run() async throws {
        try await execute {
            let document = try UsageDocument.load()
            let sources = document.sources ?? []
            guard !json else {
                CLIOut.json(
                    .array(
                        sources.map { id in
                            .object([
                                "id": .string(id),
                                "label": .optional(document.sourceMeta?[id]?.label),
                                "tool": .optional(document.sourceMeta?[id]?.tool),
                                "default": .bool(
                                    document.defaultSources?.contains(id) ?? false),
                            ])
                        }))
                return
            }
            let rows = sources.map { id in
                [id, document.sourceMeta?[id]?.label ?? id, document.sourceMeta?[id]?.tool ?? ""]
            }
            CLIOut.out(TextTable.render(headers: ["ID", "LABEL", "TOOL"], rows: rows))
        }
    }
}

struct UsageRefreshCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "refresh", abstract: "Ask the running app to re-collect usage data.")

    @Flag(name: .long, help: "Emit JSON on stdout.")
    var json = false

    @Flag(help: "Return as soon as the request is sent.")
    var noWait = false

    func run() async throws {
        try await execute {
            try AppBridge.requireHelper("refreshing usage")
            let finished = await AppBridge.awaitReply(
                IPC.Name.usageRefreshFinished, timeout: noWait ? 0.1 : 180
            ) {
                AppBridge.post(IPC.Name.requestUsageRefresh)
            }
            let completed = finished != nil
            guard !json else {
                CLIOut.json(.object(["requested": .bool(true), "completed": .bool(completed)]))
                return
            }
            CLIOut.out(completed ? "usage refreshed" : "refresh requested")
        }
    }
}
