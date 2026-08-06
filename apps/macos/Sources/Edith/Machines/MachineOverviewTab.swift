import EdithKit
import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let maximum: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let scale = max(maximum, values.max() ?? 1, 0.001)
            let step = values.count > 1 ? proxy.size.width / CGFloat(values.count - 1) : 0
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: CGFloat(index) * step,
                    y: proxy.size.height * (1 - CGFloat(min(value, scale) / scale)))
            }
            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: proxy.size.height))
                        path.addLine(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.28), color.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: UIScale.pt(1.6), lineJoin: .round))
                }
            }
        }
    }
}

struct MeterBar: View {
    let fraction: Double
    let color: Color
    let track: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(color)
                    .frame(width: max(UIScale.pt(3), proxy.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: UIScale.pt(6))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let fraction: Double?
    let history: [Double]
    let maximum: Double
    let color: Color
    let footnote: String
    let dark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: UIScale.pt(8)) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.system(size: UIScale.pt(9.5), weight: .semibold))
                    .tracking(UIScale.pt(0.7))
                    .foregroundStyle(DashSkin.inkFaint(dark))
                Spacer()
                Text(value)
                    .font(DashSkin.serif(21))
                    .foregroundStyle(DashSkin.ink(dark))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            if let fraction {
                MeterBar(fraction: fraction, color: color, track: DashSkin.line(dark))
            }
            Sparkline(values: history, maximum: maximum, color: color)
                .frame(height: UIScale.pt(46))
            if !footnote.isEmpty {
                Text(footnote)
                    .font(.system(size: UIScale.pt(10.5)))
                    .foregroundStyle(DashSkin.inkFaint(dark))
            }
        }
        .padding(UIScale.pt(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashSkin.paper2(dark), in: RoundedRectangle(cornerRadius: UIScale.pt(14)))
        .overlay {
            RoundedRectangle(cornerRadius: UIScale.pt(14)).strokeBorder(DashSkin.line(dark))
        }
    }
}

struct MachineOverviewTab: View {
    @ObservedObject var session: MachineSession
    @Environment(\.colorScheme) private var scheme
    @Environment(\.compactLayout) private var compact

    private var dark: Bool { scheme == .dark }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIScale.pt(16)) {
                if session.sample == nil, !session.state.isConnected {
                    connectionNotice
                }
                identityCard
                metricsGrid
                if let slow = session.slow, !slow.disks.isEmpty {
                    SkinCard(title: "Storage", dark: dark) { storage(slow) }
                }
                if let slow = session.slow, !slow.temps.isEmpty || slow.gpu != nil {
                    SkinCard(title: "Hardware", dark: dark) { hardware(slow) }
                }
                if !session.facts.who.isEmpty || session.facts.updatesAvailable != nil {
                    SkinCard(title: "Host", dark: dark) { hostFacts }
                }
            }
            .pageContent(compact)
        }
    }

    private var connectionNotice: some View {
        HStack(spacing: UIScale.pt(10)) {
            if session.state.isBusy {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "bolt.horizontal.circle")
                    .foregroundStyle(DashSkin.inkFaint(dark))
            }
            Text(MachineStatusStyle.label(session.state))
                .font(.system(size: UIScale.pt(12)))
                .foregroundStyle(DashSkin.inkSoft(dark))
            Spacer(minLength: 0)
            if !session.state.isBusy {
                Button("Connect") { session.start() }
                    .pointerCursor()
            }
        }
        .padding(UIScale.pt(14))
        .background(DashSkin.paper2(dark), in: RoundedRectangle(cornerRadius: UIScale.pt(12)))
    }

    private var identityCard: some View {
        HStack(spacing: UIScale.pt(10)) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: UIScale.pt(12)))
                .foregroundStyle(DashSkin.inkFaint(dark))
            Text(uptimeText)
                .font(.system(size: UIScale.pt(12.5), weight: .medium))
                .foregroundStyle(DashSkin.ink(dark))
            Spacer(minLength: 0)
            if let hello = session.hello {
                Text("\(hello.os)  ·  \(hello.arch)")
                    .font(DashSkin.mono(10.5))
                    .foregroundStyle(DashSkin.inkFaint(dark))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, UIScale.pt(14))
        .padding(.vertical, UIScale.pt(10))
        .background(DashSkin.paper2(dark), in: RoundedRectangle(cornerRadius: UIScale.pt(12)))
        .overlay {
            RoundedRectangle(cornerRadius: UIScale.pt(12)).strokeBorder(DashSkin.line(dark))
        }
    }

    private var uptimeText: String {
        guard let sample = session.sample else { return "Waiting for the first sample" }
        return "Up \(ByteFormatter.duration(sample.uptime))"
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: UIScale.pt(12)),
                GridItem(.flexible(), spacing: UIScale.pt(12)),
            ], spacing: UIScale.pt(12)
        ) {
            metricCard(
                "CPU", value: session.sample.map { String(format: "%.0f%%", $0.cpu.total) } ?? "—",
                fraction: (session.sample?.cpu.total ?? 0) / 100, history: session.cpuHistory,
                maximum: 100, color: DashSkin.accent(dark),
                footnote: session.sample.map { sample in
                    sample.cpu.steal > 1
                        ? String(format: "steal %.0f%%", sample.cpu.steal)
                        : "\(sample.cpu.cores.count) cores"
                } ?? "")
            metricCard(
                "Memory",
                value: session.sample.map { String(format: "%.0f%%", $0.mem.usedPercent) } ?? "—",
                fraction: (session.sample?.mem.usedPercent ?? 0) / 100, history: session.memHistory,
                maximum: 100, color: DashSkin.sage,
                footnote: session.sample.map {
                    "\(ByteFormatter.string($0.mem.usedKB * 1024)) of "
                        + ByteFormatter.string($0.mem.totalKB * 1024)
                } ?? "")
        }
    }

    private func metricCard(
        _ title: String, value: String, fraction: Double?, history: [Double], maximum: Double,
        color: Color, footnote: String
    ) -> some View {
        MetricCard(
            title: title, value: value, fraction: fraction, history: history, maximum: maximum,
            color: color, footnote: footnote, dark: dark)
    }

    private func storage(_ slow: MachineSlow) -> some View {
        VStack(spacing: UIScale.pt(10)) {
            ForEach(slow.disks) { disk in
                VStack(alignment: .leading, spacing: UIScale.pt(5)) {
                    HStack {
                        Text(disk.mount)
                            .font(.system(size: UIScale.pt(12), weight: .medium))
                            .foregroundStyle(DashSkin.ink(dark))
                            .lineLimit(1)
                        Spacer()
                        Text(
                            "\(ByteFormatter.string(disk.usedKB * 1024)) of "
                                + ByteFormatter.string(disk.totalKB * 1024)
                        )
                        .font(DashSkin.mono(10.5))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                    }
                    MeterBar(
                        fraction: disk.usedPercent / 100,
                        color: disk.usedPercent > 90
                            ? DashSkin.danger
                            : (disk.usedPercent > 75 ? DashSkin.warn : DashSkin.accent(dark)),
                        track: DashSkin.line(dark))
                }
            }
        }
    }

    private func network(_ sample: MachineSample) -> some View {
        VStack(spacing: UIScale.pt(6)) {
            ForEach(sample.net.ifaces.filter { !$0.virtual }, id: \.n) { iface in
                HStack {
                    Text(iface.n)
                        .font(.system(size: UIScale.pt(12)))
                        .foregroundStyle(DashSkin.ink(dark))
                    Spacer()
                    Label(ByteFormatter.rate(iface.rxBps), systemImage: "arrow.down")
                        .font(DashSkin.mono(10.5))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                    Label(ByteFormatter.rate(iface.txBps), systemImage: "arrow.up")
                        .font(DashSkin.mono(10.5))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                }
            }
        }
    }

    private func hardware(_ slow: MachineSlow) -> some View {
        VStack(alignment: .leading, spacing: UIScale.pt(8)) {
            if let gpu = slow.gpu {
                HStack {
                    Text(gpu.name)
                        .font(.system(size: UIScale.pt(12), weight: .medium))
                        .foregroundStyle(DashSkin.ink(dark))
                    Spacer()
                    Text(
                        "\(gpu.util)%  ·  \(gpu.memUsedMB) of \(gpu.memTotalMB) MB  ·  \(gpu.temp)°C"
                    )
                    .font(DashSkin.mono(10.5))
                    .foregroundStyle(DashSkin.inkFaint(dark))
                }
            }
            if let battery = slow.battery {
                HStack {
                    Text("Battery")
                        .font(.system(size: UIScale.pt(12)))
                        .foregroundStyle(DashSkin.ink(dark))
                    Spacer()
                    Text("\(battery.percent)%  ·  \(battery.status)")
                        .font(DashSkin.mono(10.5))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                }
            }
            if !slow.temps.isEmpty {
                let columns = [
                    GridItem(.adaptive(minimum: UIScale.pt(150)), spacing: UIScale.pt(8))
                ]
                LazyVGrid(columns: columns, alignment: .leading, spacing: UIScale.pt(6)) {
                    ForEach(slow.temps, id: \.label) { temp in
                        HStack(spacing: UIScale.pt(6)) {
                            Text(temp.label)
                                .font(.system(size: UIScale.pt(11)))
                                .foregroundStyle(DashSkin.inkSoft(dark))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(String(format: "%.0f°C", temp.c))
                                .font(DashSkin.mono(10.5))
                                .foregroundStyle(
                                    temp.c > 85 ? DashSkin.danger : DashSkin.inkFaint(dark))
                        }
                    }
                }
            }
        }
    }

    private var hostFacts: some View {
        VStack(alignment: .leading, spacing: UIScale.pt(6)) {
            if let updates = session.facts.updatesAvailable, updates > 0 {
                Label(
                    "\(updates) package update\(updates == 1 ? "" : "s") available",
                    systemImage: "shippingbox.and.arrow.backward"
                )
                .font(.system(size: UIScale.pt(12)))
                .foregroundStyle(DashSkin.inkSoft(dark))
            }
            ForEach(session.facts.who, id: \.self) { line in
                Label(line, systemImage: "person")
                    .font(.system(size: UIScale.pt(11.5)))
                    .foregroundStyle(DashSkin.inkFaint(dark))
            }
        }
    }
}
