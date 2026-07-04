import AppKit
import Foundation

struct LimitWindow {
    let percent: Double
    let resetsAt: Date?
}

struct RangeStat: Identifiable {
    let id: String
    let label: String
    let tokens: Double
    let cost: Double
}

struct SourceInfo: Identifiable {
    let id: String
    let label: String
}

struct DayPoint: Identifiable {
    let id: String // yyyy-mm-dd
    let date: Date
    let cost: Double
}

@MainActor
final class UsageStore: ObservableObject {
    // Limits (OAuth usage endpoint, same one Claude Code's /usage reads)
    @Published private(set) var session: LimitWindow?
    @Published private(set) var week: LimitWindow?
    @Published private(set) var limitsError: String?
    @Published private(set) var limitsUpdatedAt: Date?
    @Published private(set) var refreshingLimits = false

    // Token stats from data/usage.json
    @Published private(set) var stats: [RangeStat] = []
    @Published private(set) var sources: [SourceInfo] = []
    @Published var selectedSources: Set<String> = [] {
        didSet { recomputeStats() }
    }
    @Published private(set) var statsGeneratedAt: Date?
    @Published private(set) var statsError: String?
    @Published private(set) var calendarDays: [DayPoint] = []

    // cc-update runner
    @Published private(set) var updating = false
    @Published private(set) var log = ""

    private var defaultSources: [String] = []
    private var daily: [DailyRow] = []
    private var billingDay = 26 // matches DEFAULT_BILLING_DAY in js/state.js

    private var cachedToken: String?
    private var retryNotBefore: Date? // 429 backoff gate
    private var usageMtime: Date?
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var process: Process?
    let notifier = LimitNotifier()
    private var history = LimitsHistory()
    @Published private(set) var limitPoints: [LimitPoint] = []
    private var historyMtime: Date?

    init() {
        // 5-min limit poll; generous tolerance lets macOS coalesce wakeups.
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshLimits() }
        }
        t.tolerance = 30
        RunLoop.main.add(t, forMode: .common)
        timer = t

        // Timers don't fire during sleep; refresh immediately on wake so the
        // panel is never a whole cycle stale after the lid opens.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshLimits()
                await self?.loadStats()
            }
        }

        Task {
            await refreshLimits()
            await loadStats()
        }
    }

    /// Tab disabled → stop everything and drop the parsed data.
    func shutdown() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        process?.terminate()
        daily = []
        stats = []
        calendarDays = []
        log = ""
        usageMtime = nil
        limitPoints = []
    }

    // MARK: - Limits

    /// When the poller will actually fire next (timer schedule, pushed out by
    /// any 429 backoff). Read at render time - the card re-renders after every
    /// refresh, which is exactly when this changes.
    var nextLimitsRefresh: Date? {
        guard let fire = timer?.fireDate else { return nil }
        if let gate = retryNotBefore, gate > fire { return gate }
        return fire
    }

    /// `force` skips the 429 backoff gate - used by the manual reload button.
    func refreshLimits(force: Bool = false) async {
        if !force, let gate = retryNotBefore, gate > Date() { return }
        guard !refreshingLimits else { return }
        refreshingLimits = true
        await fetchLimitsOnce()
        // The fetch often finishes in ~200ms - hold the spinner briefly so the
        // reload visibly reacts instead of appearing to do nothing.
        try? await Task.sleep(nanoseconds: 400_000_000)
        refreshingLimits = false
    }

    private func fetchLimitsOnce() async {
        guard let token = currentToken() else {
            limitsError = "Claude Code token not found"
            return
        }
        do {
            let usage = try await Self.fetchUsage(token: token)
            apply(usage)
        } catch FetchError.unauthorized {
            cachedToken = nil // token rotated (claude /login etc.) - re-read once
            if let fresh = currentToken(), let usage = try? await Self.fetchUsage(token: fresh) {
                apply(usage)
            } else {
                limitsError = "Token expired - run claude to re-login"
                notifier.notifyTokenExpired()
            }
        } catch FetchError.rateLimited(let after) {
            // ponytail: flat backoff, no exponential ladder - endpoint 429s are rare
            retryNotBefore = Date().addingTimeInterval(after ?? 1800)
        } catch {
            limitsError = "Offline"
        }
    }

    private func apply(_ usage: OAuthUsage) {
        session = usage.fiveHour.map { LimitWindow(percent: $0.utilization ?? 0, resetsAt: Self.parseISO($0.resetsAt)) }
        week = usage.sevenDay.map { LimitWindow(percent: $0.utilization ?? 0, resetsAt: Self.parseISO($0.resetsAt)) }
        limitsError = nil
        limitsUpdatedAt = Date()
        retryNotBefore = nil
        notifier.evaluate(session: session, week: week)
        history.append(session: session, week: week)
    }

    private struct OAuthUsage: Decodable {
        struct Window: Decodable {
            let utilization: Double?
            let resetsAt: String?
            enum CodingKeys: String, CodingKey {
                case utilization
                case resetsAt = "resets_at"
            }
        }
        let fiveHour: Window?
        let sevenDay: Window?
        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    private enum FetchError: Error {
        case unauthorized
        case rateLimited(after: TimeInterval?)
        case http(Int)
    }

    private nonisolated static func fetchUsage(token: String) async throws -> OAuthUsage {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.timeoutInterval = 15
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        switch code {
        case 200: return try JSONDecoder().decode(OAuthUsage.self, from: data)
        case 401, 403: throw FetchError.unauthorized
        case 429:
            let after = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw FetchError.rateLimited(after: after)
        default: throw FetchError.http(code)
        }
    }

    // Token sources, in TokenEater's proven priority order: the `security` CLI
    // (stable Apple signing identity → no repeat keychain prompts), then the
    // legacy credentials file. Cached in memory; cleared on 401.
    private func currentToken() -> String? {
        if let t = cachedToken { return t }
        let t = Self.tokenFromSecurityCLI() ?? Self.tokenFromCredentialsFile()
        cachedToken = t
        return t
    }

    private nonisolated static func tokenFromSecurityCLI() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        guard (try? p.run()) != nil else { return nil }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return extractToken(from: data)
    }

    private nonisolated static func tokenFromCredentialsFile() -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return extractToken(from: data)
    }

    private nonisolated static func extractToken(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return nil }
        return token
    }

    static let ymdParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    nonisolated static func parseISO(_ s: String?) -> Date? {
        guard var s else { return nil }
        // The endpoint sends 6-digit fractional seconds; ISO8601DateFormatter
        // only tolerates 3, so strip the fraction entirely.
        s = s.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: s)
    }

    // MARK: - Token stats (data/usage.json)

    struct DailyRow: Decodable {
        let period: String
        let bySource: [String: [ModelRow]]
    }

    struct ModelRow: Decodable {
        let inputTokens: Double?
        let outputTokens: Double?
        let cacheCreationTokens: Double?
        let cacheReadTokens: Double?
        let cost: Double?
        var tokens: Double {
            (inputTokens ?? 0) + (outputTokens ?? 0) + (cacheCreationTokens ?? 0) + (cacheReadTokens ?? 0)
        }
    }

    private struct UsageFile: Decodable {
        let generatedAt: String?
        let sources: [String]?
        let defaultSources: [String]?
        let sourceMeta: [String: Meta]?
        let daily: [DailyRow]
        struct Meta: Decodable { let label: String? }
    }

    /// Re-parses usage.json when its mtime changed (panel open, wake, after cc-update).
    func loadStats() async {
        let url = Repo.usageJSON
        let mtime = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        if let mtime, mtime == usageMtime { return }

        let parsed: UsageFile
        do {
            // ~700 KB file - decode off the main actor.
            parsed = try await Task.detached(priority: .utility) {
                try JSONDecoder().decode(UsageFile.self, from: Data(contentsOf: url))
            }.value
        } catch {
            statsError = "usage.json missing - hit reload"
            return
        }

        usageMtime = mtime
        statsError = nil
        daily = parsed.daily
        defaultSources = parsed.defaultSources ?? parsed.sources ?? []
        let meta = parsed.sourceMeta ?? [:]
        sources = (parsed.sources ?? []).map { SourceInfo(id: $0, label: meta[$0]?.label ?? $0) }
        statsGeneratedAt = Self.parseISO(parsed.generatedAt)
        if selectedSources.isEmpty {
            selectedSources = Set(defaultSources) // triggers recomputeStats
        } else {
            recomputeStats()
        }
    }

    private func recomputeStats() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let ymd = { (d: Date) -> String in
            let c = cal.dateComponents([.year, .month, .day], from: d)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        // Monday-start week and day-26 billing cycle, matching js/compute.js + js/cycles.js.
        let dow = (cal.component(.weekday, from: today) + 5) % 7
        let weekStart = cal.date(byAdding: .day, value: -dow, to: today)!
        let cycleStart: Date = {
            let day = cal.component(.day, from: today)
            let anchor = min(billingDay, cal.range(of: .day, in: .month, for: today)!.count)
            if day >= anchor {
                return cal.date(bySetting: .day, value: anchor, of: cal.date(from: cal.dateComponents([.year, .month], from: today))!)!
            }
            let prev = cal.date(byAdding: .month, value: -1, to: today)!
            let prevAnchor = min(billingDay, cal.range(of: .day, in: .month, for: prev)!.count)
            return cal.date(from: DateComponents(
                year: cal.component(.year, from: prev), month: cal.component(.month, from: prev), day: prevAnchor))!
        }()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let ranges: [(String, String, String)] = [
            ("Today", ymd(today), ymd(today)),
            ("Yesterday", ymd(yesterday), ymd(yesterday)),
            ("This week", ymd(weekStart), ymd(today)),
            ("This cycle", ymd(cycleStart), ymd(today)),
        ]
        stats = ranges.map { label, from, to in
            var tokens = 0.0, cost = 0.0
            for row in daily where row.period >= from && row.period <= to {
                for (source, models) in row.bySource where selectedSources.contains(source) {
                    for m in models {
                        tokens += m.tokens
                        cost += m.cost ?? 0
                    }
                }
            }
            return RangeStat(id: label, label: label, tokens: tokens, cost: cost)
        }

        // Activity calendar: every day since the first data day (Monday-aligned),
        // zero-filled, source-filtered. The view scrolls horizontally when wide.
        var costByDay: [String: Double] = [:]
        for row in daily {
            var cost = 0.0
            for (source, models) in row.bySource where selectedSources.contains(source) {
                for m in models { cost += m.cost ?? 0 }
            }
            costByDay[row.period] = cost
        }
        var points: [DayPoint] = []
        var day = weekStart
        if let first = daily.map(\.period).min(),
           let firstDate = Self.ymdParser.date(from: first) {
            let start = cal.startOfDay(for: firstDate)
            let dow = (cal.component(.weekday, from: start) + 5) % 7
            day = cal.date(byAdding: .day, value: -dow, to: start)!
        }
        while day <= today {
            let key = ymd(day)
            points.append(DayPoint(id: key, date: day, cost: costByDay[key] ?? 0))
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        calendarDays = points
    }

    /// Last-24h limit curve for the panel chart; mtime-gated like loadStats.
    func loadLimitHistory() async {
        let url = LimitsHistory.url
        let mtime = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        if let mtime, mtime == historyMtime { return }
        historyMtime = mtime
        let since = Date().addingTimeInterval(-24 * 3600)
        let points = await Task.detached(priority: .utility) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [LimitPoint]() }
            return LimitsHistory.parse(text, since: since)
        }.value
        limitPoints = points
    }

    // MARK: - Open dashboard with current filters

    /// Mirrors js/params.js: default source selection → clean URL; anything
    /// else persists as ?sources=a,b so the browser view matches the panel.
    func openDashboard() {
        var components = URLComponents(url: Repo.dashboard, resolvingAgainstBaseURL: false)!
        if selectedSources != Set(defaultSources) {
            let picked = sources.map(\.id).filter { selectedSources.contains($0) }
            components.queryItems = [URLQueryItem(name: "sources", value: picked.joined(separator: ","))]
        }
        guard let url = components.url else { return }
        // Route through the default *browser*, not the default .html handler.
        if let browser = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://apple.com")!) {
            NSWorkspace.shared.open([url], withApplicationAt: browser, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - cc-update

    func runUpdate() {
        guard !updating else { return }
        updating = true
        log = ""

        let p = Process()
        p.executableURL = Repo.ccUpdate
        p.currentDirectoryURL = Repo.root
        p.qualityOfService = .utility // keep the panel snappy while it runs
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                guard let self else { return }
                self.log += text
                if self.log.count > 20_000 { self.log = String(self.log.suffix(16_000)) }
            }
        }
        p.terminationHandler = { [weak self] proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                guard let self else { return }
                self.updating = false
                self.process = nil
                if proc.terminationStatus != 0 {
                    self.log += "\n✖ cc-update exited with status \(proc.terminationStatus)"
                }
                await self.loadStats()
            }
        }
        do {
            try p.run()
            process = p
        } catch {
            updating = false
            log = "✖ could not launch cc-update: \(error.localizedDescription)"
        }
    }
}
