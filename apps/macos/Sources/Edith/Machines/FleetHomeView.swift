import EdithKit
import SwiftUI

struct FleetHomeView: View {
    @ObservedObject var model: MachinesModel
    let onSelect: (UUID) -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.compactLayout) private var compact
    @State private var tick = 0

    private var dark: Bool { scheme == .dark }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIScale.pt(16)) {
                summaryTiles
                if !model.fleet.alerts.isEmpty { alertsCard }
                machinesCard
            }
            .pageContent(compact)
        }
        .task {
            while !Task.isCancelled {
                tick += 1
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private var summaryTiles: some View {
        let fleet = model.fleet
        return LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: UIScale.pt(210)), spacing: UIScale.pt(12))
            ], spacing: UIScale.pt(12)
        ) {
            tile(
                "Machines", value: "\(fleet.machinesOnline)/\(fleet.machinesTotal)",
                caption: "online", fraction: nil, color: DashSkin.accent(dark))
            tile(
                "CPU", value: String(format: "%.0f%%", fleet.cpuPercent),
                caption: "\(fleet.totalCores) cores total",
                fraction: fleet.cpuPercent / 100, color: DashSkin.accent(dark))
            tile(
                "Memory", value: ByteFormatter.string(fleet.memoryUsedKB * 1024),
                caption: "of \(ByteFormatter.string(fleet.memoryTotalKB * 1024))",
                fraction: fleet.memoryPercent / 100, color: DashSkin.sage)
            tile(
                "Storage", value: ByteFormatter.string(fleet.diskUsedKB * 1024),
                caption: "of \(ByteFormatter.string(fleet.diskTotalKB * 1024))",
                fraction: fleet.diskPercent / 100,
                color: fleet.diskPercent > 90 ? DashSkin.danger : DashSkin.gold)
            if fleet.containersTotal > 0 {
                tile(
                    "Containers", value: "\(fleet.containersRunning)",
                    caption: "of \(fleet.containersTotal) running", fraction: nil,
                    color: DashSkin.accentDeep(dark))
            }
            if fleet.swapTotalKB > 0 {
                tile(
                    "Swap", value: ByteFormatter.string(fleet.swapUsedKB * 1024),
                    caption: "of \(ByteFormatter.string(fleet.swapTotalKB * 1024))",
                    fraction: fleet.swapPercent / 100, color: DashSkin.inkFaint(dark))
            }
        }
    }

    private func tile(
        _ title: String, value: String, caption: String, fraction: Double?, color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: UIScale.pt(7)) {
            Text(title.uppercased())
                .font(.system(size: UIScale.pt(9.5), weight: .semibold))
                .tracking(UIScale.pt(0.7))
                .foregroundStyle(DashSkin.inkFaint(dark))
            Text(value)
                .font(DashSkin.serif(24))
                .foregroundStyle(DashSkin.ink(dark))
                .monospacedDigit()
                .contentTransition(.numericText())
            if let fraction {
                MeterBar(fraction: fraction, color: color, track: DashSkin.line(dark))
            }
            Text(caption)
                .font(.system(size: UIScale.pt(10.5)))
                .foregroundStyle(DashSkin.inkFaint(dark))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIScale.pt(14))
        .background(DashSkin.paper2(dark), in: RoundedRectangle(cornerRadius: UIScale.pt(14)))
        .overlay {
            RoundedRectangle(cornerRadius: UIScale.pt(14)).strokeBorder(DashSkin.line(dark))
        }
    }

    private var alertsCard: some View {
        SkinCard(title: "Needs attention", dark: dark) {
            VStack(alignment: .leading, spacing: UIScale.pt(7)) {
                ForEach(model.fleet.alerts) { alert in
                    HStack(spacing: UIScale.pt(8)) {
                        Image(systemName: alert.symbol)
                            .font(.system(size: UIScale.pt(11)))
                            .foregroundStyle(
                                alert.kind == .updates ? DashSkin.gold : DashSkin.warn
                            )
                            .frame(width: UIScale.pt(16))
                        Text(alert.machineName)
                            .font(.system(size: UIScale.pt(12), weight: .medium))
                            .foregroundStyle(DashSkin.ink(dark))
                        Text(alert.detail)
                            .font(.system(size: UIScale.pt(11.5)))
                            .foregroundStyle(DashSkin.inkFaint(dark))
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var machinesCard: some View {
        SkinCard(title: "Machines", dark: dark) {
            VStack(spacing: UIScale.pt(0)) {
                ForEach(FleetMath.sortedByPressure(model.snapshots), id: \.id) { snapshot in
                    FleetMachineRow(snapshot: snapshot, dark: dark) {
                        onSelect(snapshot.id)
                    }
                    if snapshot.id != FleetMath.sortedByPressure(model.snapshots).last?.id {
                        Divider().opacity(0.25)
                    }
                }
            }
        }
    }
}

private struct FleetMachineRow: View {
    let snapshot: MachineSnapshot
    let dark: Bool
    let onOpen: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: UIScale.pt(12)) {
                Image(systemName: snapshot.isLocal ? "laptopcomputer" : "server.rack")
                    .font(.system(size: UIScale.pt(13)))
                    .foregroundStyle(DashSkin.inkSoft(dark))
                    .frame(width: UIScale.pt(18))
                VStack(alignment: .leading, spacing: UIScale.pt(1)) {
                    Text(snapshot.name)
                        .font(.system(size: UIScale.pt(12.5), weight: .medium))
                        .foregroundStyle(DashSkin.ink(dark))
                    Text(snapshot.online ? snapshot.os : "Not connected")
                        .font(.system(size: UIScale.pt(10.5)))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                        .lineLimit(1)
                }
                .frame(width: UIScale.pt(190), alignment: .leading)
                if snapshot.online {
                    meter("CPU", percent: snapshot.cpuPercent, color: DashSkin.accent(dark))
                    meter("MEM", percent: snapshot.memoryPercent, color: DashSkin.sage)
                    meter(
                        "DISK", percent: snapshot.diskPercent,
                        color: snapshot.diskPercent > 90 ? DashSkin.danger : DashSkin.gold)
                    Text("\(snapshot.cores) cores")
                        .font(DashSkin.mono(10))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                        .frame(width: UIScale.pt(60), alignment: .trailing)
                } else {
                    Text("Offline")
                        .font(.system(size: UIScale.pt(11)))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: UIScale.pt(9)))
                    .foregroundStyle(DashSkin.inkFaint(dark))
            }
            .padding(.vertical, UIScale.pt(8))
            .padding(.horizontal, UIScale.pt(4))
            .background(
                RoundedRectangle(cornerRadius: UIScale.pt(7))
                    .fill(hovering ? DashSkin.inkFaint(dark).opacity(0.07) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
    }

    private func meter(_ label: String, percent: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: UIScale.pt(3)) {
            HStack(spacing: UIScale.pt(4)) {
                Text(label)
                    .font(.system(size: UIScale.pt(8.5), weight: .semibold))
                    .foregroundStyle(DashSkin.inkFaint(dark))
                Text(String(format: "%.0f%%", percent))
                    .font(DashSkin.mono(9.5))
                    .foregroundStyle(DashSkin.inkSoft(dark))
            }
            MeterBar(fraction: percent / 100, color: color, track: DashSkin.line(dark))
        }
        .frame(maxWidth: .infinity)
    }
}

struct FleetChip: View {
    let selected: Bool
    let dark: Bool
    let onSelect: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: UIScale.pt(8)) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: UIScale.pt(13)))
                    .foregroundStyle(selected ? DashSkin.accent(dark) : DashSkin.inkSoft(dark))
                VStack(alignment: .leading, spacing: UIScale.pt(1)) {
                    Text("All machines")
                        .font(.system(size: UIScale.pt(12.5), weight: .medium))
                        .foregroundStyle(DashSkin.ink(dark))
                    Text("Summary")
                        .font(.system(size: UIScale.pt(10.5)))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                }
            }
            .padding(.horizontal, UIScale.pt(11))
            .padding(.vertical, UIScale.pt(8))
            .background(
                selected ? DashSkin.paper2(dark) : DashSkin.paper2(dark).opacity(0.55),
                in: RoundedRectangle(cornerRadius: UIScale.pt(11))
            )
            .overlay {
                RoundedRectangle(cornerRadius: UIScale.pt(11))
                    .strokeBorder(
                        selected ? DashSkin.accent(dark).opacity(0.55) : DashSkin.line(dark),
                        lineWidth: UIScale.pt(selected ? 1.4 : 1))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
    }
}
