import SwiftUI

struct UsageView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var showLog = false
    @AppStorage("presenterMode") private var presenter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            limitsCard
            if !store.calendarDays.isEmpty {
                activityCard
            }
            usageCard
        }
        .task { await store.loadStats() } // panel open → pick up fresh snapshots
    }

    // MARK: - Limits

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                eyebrow("LIMITS")
                Spacer()
                if let at = store.limitsUpdatedAt {
                    let next = store.nextLimitsRefresh
                        .map { $0.formatted(date: .omitted, time: .shortened) } ?? "—"
                    Text("updated \(at.formatted(date: .omitted, time: .shortened)) · next \(next)")
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                Button {
                    Task { await store.refreshLimits(force: true) }
                } label: {
                    if store.refreshingLimits {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(store.refreshingLimits)
                .help("Refresh limits now")
            }
            limitRow("Session", window: store.session)
            limitRow("Week", window: store.week)
            if let err = store.limitsError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .card()
    }

    private func limitRow(_ label: String, window: LimitWindow?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                if let w = window {
                    if let reset = w.resetsAt, reset > Date() {
                        // Live countdown, "2d 3:45:12" above 24h. TimelineView only
                        // ticks while the panel is visible; monospacedDigit keeps
                        // the row width stable as seconds change.
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(countdown(from: context.date, to: reset))
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Text("\(Int(w.percent))%")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(color(for: w.percent))
                        .frame(minWidth: 34, alignment: .trailing)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            gauge(percent: window?.percent ?? 0)
        }
    }

    private func gauge(percent: Double) -> some View {
        let fill = color(for: percent)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(fill)
                    .frame(width: max(5, geo.size.width * min(percent / 100, 1)))
                    .shadow(color: fill.opacity(0.5), radius: 3) // the one glow
            }
        }
        .frame(height: 5)
    }

    private func countdown(from now: Date, to reset: Date) -> String {
        let s = max(0, Int(reset.timeIntervalSince(now)))
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60, sec = s % 60
        if d > 0 { return String(format: "%dd %d:%02d:%02d", d, h, m, sec) }
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private func color(for percent: Double) -> Color {
        percent >= 90 ? .red : percent >= 70 ? .orange : .green
    }

    // MARK: - Activity calendar

    private var activityCard: some View {
        let days = store.calendarDays
        let weeks: [[DayPoint]] = stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
        // GitHub-style intensity: quartiles of the non-zero days → 4 steps of one hue.
        let nonzero = days.map(\.cost).filter { $0 > 0 }.sorted()
        let quartile = { (p: Double) -> Double in
            nonzero.isEmpty ? 0 : nonzero[Int(Double(nonzero.count - 1) * p)]
        }
        let cuts = [quartile(0.25), quartile(0.5), quartile(0.75)]
        let total = days.reduce(0) { $0 + $1.cost }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                eyebrow("ACTIVITY")
                Spacer()
                Text(String(format: "$%.0f · %d weeks", total, weeks.count))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .presenterBlur(presenter)
            }
            HStack(alignment: .top, spacing: 3) {
                VStack(spacing: 3) {
                    ForEach(Array(["M", "", "W", "", "F", "", "S"].enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .frame(width: 12, height: 15)
                    }
                }
                .padding(.top, 13) // clears the month-label row
                // Full history since the first data day; lands on the newest week.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                            VStack(spacing: 3) {
                                Text(monthLabel(for: weeks, at: index))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                                    .frame(height: 10)
                                ForEach(week) { day in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(cellColor(day.cost, cuts: cuts))
                                        .frame(width: 15, height: 15)
                                        .help(presenter
                                            ? day.date.formatted(.dateTime.day().month())
                                            : "\(day.date.formatted(.dateTime.day().month())) — $\(String(format: "%.2f", day.cost))")
                                }
                            }
                        }
                    }
                }
                // ponytail: ~18 week columns fit the card; under that the anchor
                // must be leading or narrow content gets shoved to the right edge
                .defaultScrollAnchor(weeks.count > 18 ? .trailing : .leading)
            }
        }
        .card()
    }

    private func monthLabel(for weeks: [[DayPoint]], at index: Int) -> String {
        guard let first = weeks[index].first?.date else { return "" }
        let month = Calendar.current.component(.month, from: first)
        if index > 0, let prev = weeks[index - 1].first?.date,
           Calendar.current.component(.month, from: prev) == month {
            return ""
        }
        return first.formatted(.dateTime.month(.abbreviated))
    }

    private func cellColor(_ cost: Double, cuts: [Double]) -> Color {
        if cost <= 0 { return .white.opacity(0.06) }
        if cost <= cuts[0] { return .accentColor.opacity(0.25) }
        if cost <= cuts[1] { return .accentColor.opacity(0.45) }
        if cost <= cuts[2] { return .accentColor.opacity(0.7) }
        return .accentColor
    }

    // MARK: - Usage stats

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                eyebrow("USAGE")
                Spacer()
                Button {
                    store.runUpdate()
                } label: {
                    if store.updating {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(store.updating)
                .help("Run cc-update")
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showLog.toggle() }
                } label: {
                    Image(systemName: "terminal")
                        .foregroundStyle(showLog ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Show cc-update logs")
                Button {
                    store.openDashboard()
                    dismissPanel()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Open dashboard in browser (keeps filters)")
            }
            .font(.system(size: 12))

            HStack {
                sourcePicker
                Spacer()
                if let at = store.statsGeneratedAt {
                    Text("Data from \(at.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            if showLog {
                logView
            }

            if let err = store.statsError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else {
                VStack(spacing: 7) {
                    ForEach(store.stats) { stat in
                        HStack {
                            Text(stat.label)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(stat.tokens.compactTokens)
                                .monospacedDigit()
                                .presenterBlur(presenter)
                            Text(String(format: "$%.2f", stat.cost))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 76, alignment: .trailing)
                                .presenterBlur(presenter)
                        }
                        .font(.system(size: 12))
                    }
                }
            }
        }
        .card()
    }

    private var sourcePicker: some View {
        Menu {
            ForEach(store.sources) { source in
                Button {
                    if store.selectedSources.contains(source.id) {
                        if store.selectedSources.count > 1 { store.selectedSources.remove(source.id) }
                    } else {
                        store.selectedSources.insert(source.id)
                    }
                } label: {
                    HStack {
                        if store.selectedSources.contains(source.id) {
                            Image(systemName: "checkmark")
                        }
                        Text(source.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(sourceSummary)
                    .lineLimit(1)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var sourceSummary: String {
        let picked = store.sources.filter { store.selectedSources.contains($0.id) }
        if picked.count == store.sources.count, !picked.isEmpty { return "All sources" }
        guard let first = picked.first else { return "Sources" }
        return picked.count == 1 ? first.label : "\(first.label) +\(picked.count - 1)"
    }

    private var logView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                Text(store.log.isEmpty ? "No output yet — hit ↻" : store.log)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .id("end")
                    .onChange(of: store.log) {
                        proxy.scrollTo("end", anchor: .bottom)
                    }
            }
        }
        .frame(height: 110)
        .padding(6)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }
}

extension Double {
    /// 12_345_678 → "12.3M" — token-count formatting like the dashboard's.
    var compactTokens: String {
        switch self {
        case 1e9...: return String(format: "%.2fB", self / 1e9)
        case 1e6...: return String(format: "%.1fM", self / 1e6)
        case 1e3...: return String(format: "%.1fK", self / 1e3)
        default: return String(format: "%.0f", self)
        }
    }
}
