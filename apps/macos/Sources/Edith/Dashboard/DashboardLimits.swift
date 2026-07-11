import Charts
import EdithKit
import SwiftUI

struct DashLimitPoint: Identifiable {
    let t: Date
    let s: Double?
    let w: Double?
    let sr: Date?
    let wr: Date?
    var id: TimeInterval { t.timeIntervalSince1970 }
}

struct ResetMarker: Identifiable {
    let t: Date
    let session: Bool
    var id: String { "\(t.timeIntervalSince1970)-\(session)" }
}

enum DashLimits {
    private struct Row: Decodable {
        let ts: String
        let s: Double?
        let w: Double?
        let sr: String?
        let wr: String?
    }

    static func loadAll() -> [DashLimitPoint] {
        guard let text = try? String(contentsOf: LimitsHistory.url, encoding: .utf8) else {
            return []
        }
        let dec = JSONDecoder()
        var out: [DashLimitPoint] = []
        for line in text.split(separator: "\n") {
            guard let r = try? dec.decode(Row.self, from: Data(line.utf8)),
                let t = EdithDate.parseISO(r.ts)
            else { continue }
            out.append(
                DashLimitPoint(
                    t: t, s: r.s, w: r.w,
                    sr: r.sr.flatMap(EdithDate.parseISO), wr: r.wr.flatMap(EdithDate.parseISO)))
        }
        return out.sorted { $0.t < $1.t }
    }

    static func loadLatest() -> DashLimitPoint? {
        let text = FileTail.read(LimitsHistory.url, maxBytes: 8192)
        let dec = JSONDecoder()
        for line in text.split(separator: "\n").reversed() {
            guard let r = try? dec.decode(Row.self, from: Data(line.utf8)),
                let t = EdithDate.parseISO(r.ts)
            else { continue }
            return DashLimitPoint(
                t: t, s: r.s, w: r.w,
                sr: r.sr.flatMap(EdithDate.parseISO), wr: r.wr.flatMap(EdithDate.parseISO))
        }
        return nil
    }

    static func downsample(_ rows: [DashLimitPoint], now: Date, rawWindow: TimeInterval = 7 * 86400)
        -> [DashLimitPoint]
    {
        let cutoff = now.addingTimeInterval(-rawWindow)
        var buckets: [TimeInterval: DashLimitPoint] = [:]
        var raw: [DashLimitPoint] = []
        for r in rows {
            if r.t >= cutoff {
                raw.append(r)
                continue
            }
            let b = (r.t.timeIntervalSince1970 / 3600).rounded(.down) * 3600
            if let cur = buckets[b] {
                buckets[b] = DashLimitPoint(
                    t: Date(timeIntervalSince1970: b),
                    s: [cur.s, r.s].compactMap { $0 }.max(),
                    w: [cur.w, r.w].compactMap { $0 }.max(),
                    sr: r.sr, wr: r.wr)
            } else {
                buckets[b] = DashLimitPoint(
                    t: Date(timeIntervalSince1970: b), s: r.s, w: r.w, sr: r.sr, wr: r.wr)
            }
        }
        return (Array(buckets.values) + raw).sorted { $0.t < $1.t }
    }

    static func markers(_ pts: [DashLimitPoint], minGap: TimeInterval = 20 * 60) -> [ResetMarker] {
        guard pts.count > 1 else { return [] }
        var out: [ResetMarker] = []
        var lastSession: Date?
        var lastWeekly: Date?
        for i in 1..<pts.count {
            let p = pts[i - 1]
            let q = pts[i]
            if let a = p.sr, let b = q.sr, a != b,
                lastSession.map({ q.t.timeIntervalSince($0) > minGap }) ?? true
            {
                out.append(ResetMarker(t: q.t, session: true))
                lastSession = q.t
            }
            if let a = p.wr, let b = q.wr, a != b,
                lastWeekly.map({ q.t.timeIntervalSince($0) > minGap }) ?? true
            {
                out.append(ResetMarker(t: q.t, session: false))
                lastWeekly = q.t
            }
        }
        return out
    }
}

struct SessionDialsView: View {
    let dark: Bool
    @AppStorage("warnPercent") private var warn = 60
    @AppStorage("critPercent") private var crit = 85
    @State private var point: DashLimitPoint?

    var body: some View {
        HStack(spacing: 18) {
            dial("SESSION", pct: point?.s, reset: point?.sr)
            dial("WEEK", pct: point?.w, reset: point?.wr)
        }
        .task { point = DashLimits.loadLatest() }
    }

    private func dial(_ label: String, pct: Double?, reset: Date?) -> some View {
        let p = pct ?? 0
        return VStack(spacing: 6) {
            ZStack {
                Circle().stroke(DashSkin.line(dark), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(p / 100, 1))
                    .stroke(color(for: p), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: p)
                Text(pct != nil ? "\(Int(p))%" : "-")
                    .font(DashSkin.serif(18)).foregroundStyle(DashSkin.ink(dark))
                    .monospacedDigit()
            }
            .frame(width: 66, height: 66)
            Text(label).font(DashSkin.mono(9)).tracking(1.2)
                .foregroundStyle(DashSkin.inkFaint(dark))
            if let reset, reset > Date() {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(countdown(from: ctx.date, to: reset))
                        .font(DashSkin.mono(9)).foregroundStyle(DashSkin.inkSoft(dark)).lineLimit(1)
                }
            } else {
                Text(" ").font(DashSkin.mono(9))
            }
        }
    }

    private func color(for percent: Double) -> Color {
        if percent >= Double(crit) { return .red }
        if percent >= Double(warn) { return .orange }
        return DashSkin.accent(dark)
    }

    private func countdown(from now: Date, to reset: Date) -> String {
        let s = max(0, Int(reset.timeIntervalSince(now)))
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60, sec = s % 60
        if d > 0 { return String(format: "%dd %d:%02d", d, h, m) }
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

struct LimitsCardView: View {
    let theme: Color
    let dark: Bool
    @AppStorage("warnPercent") private var warn = 60
    @AppStorage("critPercent") private var crit = 85
    @State private var all: [DashLimitPoint] = []
    @State private var downsampled: [DashLimitPoint] = []
    @State private var visible: [DashLimitPoint] = []
    @State private var samples: [Sample] = []
    @State private var marks: [ResetMarker] = []
    @State private var range = "24h"
    @State private var selected: Date?

    private var sessionC: Color { DashSkin.accent(dark) }
    private let weeklyC = DashPalette.color("#c89b3c")
    private let ranges: [(String, TimeInterval?)] = [
        ("24h", 86400), ("7d", 7 * 86400), ("30d", 30 * 86400), ("All", nil),
    ]

    struct Sample: Identifiable {
        let t: Date
        let v: Double
        let series: String
        var id: String { "\(series)-\(t.timeIntervalSince1970)" }
    }

    var body: some View {
        SkinCard(title: "Rate limits - session & weekly", dark: dark) {
            if all.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        segmented
                        Spacer()
                        readout
                    }
                    chart
                }
            } else {
                Text("Collecting limit history…")
                    .font(.system(size: 12)).foregroundStyle(DashSkin.inkFaint(dark))
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .task {
            all = DashLimits.loadAll()
            let now = all.last?.t ?? Date()
            downsampled = DashLimits.downsample(all, now: now)
            rebuildVisible()
        }
        .onChange(of: range) {
            selected = nil
            rebuildVisible()
        }
    }

    private func rebuildVisible() {
        let now = all.last?.t ?? Date()
        let ms = ranges.first { $0.0 == range }?.1 ?? nil
        let pts =
            ms.map { m in downsampled.filter { $0.t >= now.addingTimeInterval(-m) } }
            ?? downsampled
        visible = pts
        let start = pts.first?.t ?? now
        let spanDays = now.timeIntervalSince(start) / 86400
        marks = DashLimits.markers(pts).filter { !$0.session || spanDays <= 7 }
        samples = pts.flatMap { p -> [Sample] in
            [
                p.s.map { Sample(t: p.t, v: $0, series: "Session") },
                p.w.map { Sample(t: p.t, v: $0, series: "Weekly") },
            ].compactMap { $0 }
        }
    }

    private var segmented: some View {
        HStack(spacing: 6) {
            ForEach(ranges, id: \.0) { name, _ in
                Button(name) { range = name }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .font(.system(size: 11, weight: range == name ? .semibold : .regular))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(
                        range == name
                            ? AnyShapeStyle(theme.opacity(0.9))
                            : AnyShapeStyle(.primary.opacity(0.06)),
                        in: Capsule()
                    )
                    .foregroundStyle(
                        range == name ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            }
        }
    }

    private var readout: some View {
        let point = selected.flatMap { d in
            visible.min(by: { abs($0.t.timeIntervalSince(d)) < abs($1.t.timeIntervalSince(d)) })
        }
        return Group {
            if let point {
                HStack(spacing: 10) {
                    Text(point.t.formatted(.dateTime.month().day().hour().minute()))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                    if let s = point.s { Text("S \(Int(s))%").foregroundStyle(sessionC) }
                    if let w = point.w { Text("W \(Int(w))%").foregroundStyle(weeklyC) }
                }
            } else {
                Text("Drag chart to inspect").foregroundStyle(DashSkin.inkFaint(dark))
            }
        }
        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
    }

    private var chart: some View {
        let now = all.last?.t ?? Date()
        let start = visible.first?.t ?? now
        let spanDays = now.timeIntervalSince(start) / 86400
        return Chart {
            ForEach(marks) { m in
                RuleMark(x: .value("Reset", m.t))
                    .foregroundStyle(m.session ? sessionC.opacity(0.3) : weeklyC.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            RuleMark(y: .value("Warn", warn))
                .foregroundStyle(.orange.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            RuleMark(y: .value("Crit", crit))
                .foregroundStyle(.red.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            ForEach(samples) { s in
                LineMark(
                    x: .value("Time", s.t),
                    y: .value("Percent", s.v),
                    series: .value("Series", s.series)
                )
                .interpolationMethod(.stepEnd)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .foregroundStyle(by: .value("Series", s.series))
            }
        }
        .chartForegroundStyleScale(["Session": sessionC, "Weekly": weeklyC])
        .chartYScale(domain: 0...100)
        .chartXScale(domain: start...now)
        .chartXSelection(value: $selected)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine().foregroundStyle(.primary.opacity(0.08))
                AxisValueLabel {
                    if let v = value.as(Int.self) { Text("\(v)%").font(.system(size: 8)) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: spanDays < 2 ? 5 : 6)) { value in
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(tick(d, spanDays: spanDays)).font(.system(size: 8)).foregroundStyle(
                            .tertiary)
                    }
                }
            }
        }
        .chartLegend(position: .top, alignment: .trailing, spacing: 6)
        .frame(height: 220)
    }

    private func tick(_ d: Date, spanDays: Double) -> String {
        let cal = Calendar.current
        if spanDays < 2 {
            return String(format: "%02d:00", cal.component(.hour, from: d))
        }
        return "\(cal.component(.month, from: d))/\(cal.component(.day, from: d))"
    }
}
