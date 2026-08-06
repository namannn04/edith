import AppKit
import EdithKit
import SwiftUI

enum DockerSection: String, CaseIterable, Identifiable {
    case containers
    case images
    case volumes

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct MachineDockerTab: View {
    @ObservedObject var session: MachineSession
    @Environment(\.colorScheme) private var scheme
    @Environment(\.compactLayout) private var compact
    @State private var section = DockerSection.containers
    @State private var query = ""
    @State private var busyIDs: Set<String> = []
    @State private var error: String?
    @State private var logsFor: DockerContainer?
    @State private var terminalFor: DockerContainer?
    @State private var pendingRemoval: DockerContainer?

    private var dark: Bool { scheme == .dark }

    var body: some View {
        Group {
            switch session.docker.status {
            case .available:
                available
            case .missing:
                notice(
                    "Docker is not installed on this machine.",
                    detail: "Install Docker Engine there and this tab fills in automatically.",
                    symbol: "shippingbox")
            case .permissionDenied:
                notice(
                    "This user cannot reach the Docker socket.",
                    detail:
                        "Run sudo usermod -aG docker $USER on the machine, then log out and back in.",
                    symbol: "lock")
            case let .daemonDown(message):
                notice(
                    message, detail: "Start the Docker service on the machine and refresh.",
                    symbol: "exclamationmark.triangle")
            }
        }
        .sheet(item: $logsFor) { container in
            DockerLogsSheet(session: session, container: container)
        }
        .sheet(item: $terminalFor) { container in
            ContainerTerminalSheet(session: session, container: container)
        }
        .confirmationDialog(
            "Remove \(pendingRemoval?.displayName ?? "container")?",
            isPresented: Binding(
                get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let container = pendingRemoval {
                    perform(DockerCommands.lifecycle("rm", id: container.id), on: container.id)
                }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        }
    }

    private var available: some View {
        VStack(spacing: UIScale.pt(0)) {
            controls
            if let error {
                Text(error)
                    .font(.system(size: UIScale.pt(11)))
                    .foregroundStyle(DashSkin.inkSoft(dark))
                    .padding(.horizontal, PageMetrics.gutter(compact))
                    .padding(.vertical, UIScale.pt(7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DashSkin.danger.opacity(0.12))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UIScale.pt(14)) {
                    switch section {
                    case .containers: containersSection
                    case .images: imagesSection
                    case .volumes: volumesSection
                    }
                    if !session.diskUsage.isEmpty { diskUsageStrip }
                }
                .pageContent(compact)
            }
        }
        .task {
            await session.refreshImagesAndVolumes()
        }
    }

    private var controls: some View {
        HStack(spacing: UIScale.pt(10)) {
            Picker("", selection: $section) {
                ForEach(DockerSection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: UIScale.pt(260))
            SearchField(placeholder: "Filter", text: $query)
                .frame(maxWidth: UIScale.pt(220))
            Spacer(minLength: 0)
            Button {
                session.refreshDockerNow()
                Task { await session.refreshImagesAndVolumes() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(HoverButtonStyle())
            .help("Refresh")
        }
        .padding(.horizontal, PageMetrics.gutter(compact))
        .padding(.bottom, UIScale.pt(12))
    }

    private var filteredContainers: [DockerContainer] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return session.containers }
        return session.containers.filter {
            $0.displayName.localizedCaseInsensitiveContains(trimmed)
                || $0.image.localizedCaseInsensitiveContains(trimmed)
                || ($0.composeProject ?? "").localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var containerGroups: [(project: String?, containers: [DockerContainer])] {
        let grouped = Dictionary(grouping: filteredContainers) { $0.composeProject }
        let projects = grouped.keys.compactMap { $0 }.sorted()
        var result: [(String?, [DockerContainer])] = projects.map { project in
            (project, (grouped[project] ?? []).sorted { $0.displayName < $1.displayName })
        }
        if let standalone = grouped[nil], !standalone.isEmpty {
            result.append((nil, standalone.sorted { $0.displayName < $1.displayName }))
        }
        return result
    }

    @ViewBuilder
    private var containersSection: some View {
        if session.containers.isEmpty {
            emptyRow("No containers on this machine yet.")
        }
        ForEach(containerGroups, id: \.project) { group in
            SkinCard(
                title: group.project ?? "Standalone",
                note: group.project == nil
                    ? nil
                    : "\(group.containers.count) service"
                        + (group.containers.count == 1 ? "" : "s"), dark: dark
            ) {
                VStack(spacing: UIScale.pt(0)) {
                    ForEach(group.containers) { container in
                        ContainerRow(
                            container: container, dark: dark,
                            busy: busyIDs.contains(container.id),
                            onAction: { action in
                                perform(
                                    DockerCommands.lifecycle(action, id: container.id),
                                    on: container.id)
                            },
                            onRemove: { pendingRemoval = container },
                            onLogs: { logsFor = container },
                            onShell: { terminalFor = container })
                        if container.id != group.containers.last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
        }
    }

    private var imagesSection: some View {
        SkinCard(title: "Images", dark: dark) {
            VStack(spacing: UIScale.pt(0)) {
                let items = session.images.filter {
                    query.isEmpty || $0.displayName.localizedCaseInsensitiveContains(query)
                }
                if items.isEmpty { emptyRow("No images.") }
                ForEach(items) { image in
                    HStack(spacing: UIScale.pt(10)) {
                        Image(systemName: "square.stack.3d.up")
                            .foregroundStyle(DashSkin.inkFaint(dark))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(image.displayName)
                                .font(.system(size: UIScale.pt(12.5)))
                                .foregroundStyle(DashSkin.ink(dark))
                                .lineLimit(1)
                            Text("\(image.shortID) · \(image.createdSince)")
                                .font(DashSkin.mono(10))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                        }
                        Spacer(minLength: 0)
                        Text(ByteFormatter.string(image.sizeBytes))
                            .font(DashSkin.mono(11))
                            .foregroundStyle(DashSkin.inkSoft(dark))
                        Button {
                            perform(
                                DockerCommands.removeImage(image.id, force: false), on: image.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(HoverButtonStyle())
                        .help("Remove image")
                    }
                    .padding(.vertical, UIScale.pt(6))
                    if image.id != items.last?.id { Divider().opacity(0.25) }
                }
            }
        }
    }

    private var volumesSection: some View {
        SkinCard(title: "Volumes", dark: dark) {
            VStack(spacing: UIScale.pt(0)) {
                let items = session.volumes.filter {
                    query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
                }
                if items.isEmpty { emptyRow("No volumes.") }
                ForEach(items) { volume in
                    HStack(spacing: UIScale.pt(10)) {
                        Image(systemName: "externaldrive")
                            .foregroundStyle(DashSkin.inkFaint(dark))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(volume.name)
                                .font(.system(size: UIScale.pt(12.5)))
                                .foregroundStyle(DashSkin.ink(dark))
                                .lineLimit(1)
                            Text(volume.driver)
                                .font(DashSkin.mono(10))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                        }
                        Spacer(minLength: 0)
                        if volume.inUse {
                            Text("In use")
                                .font(.system(size: UIScale.pt(10), weight: .medium))
                                .padding(.horizontal, UIScale.pt(6))
                                .padding(.vertical, UIScale.pt(2))
                                .background(
                                    DashSkin.sage.opacity(0.18),
                                    in: Capsule()
                                )
                                .foregroundStyle(DashSkin.sage)
                        }
                        if let size = volume.sizeBytes {
                            Text(ByteFormatter.string(size))
                                .font(DashSkin.mono(11))
                                .foregroundStyle(DashSkin.inkSoft(dark))
                        }
                        Button {
                            perform(DockerCommands.removeVolume(volume.name), on: volume.name)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(HoverButtonStyle())
                        .disabled(volume.inUse)
                        .help(volume.inUse ? "In use by a container" : "Remove volume")
                    }
                    .padding(.vertical, UIScale.pt(6))
                    if volume.id != items.last?.id { Divider().opacity(0.25) }
                }
            }
        }
    }

    private var diskUsageStrip: some View {
        HStack(spacing: UIScale.pt(12)) {
            ForEach(session.diskUsage, id: \.type) { usage in
                VStack(alignment: .leading, spacing: UIScale.pt(2)) {
                    Text(usage.type.uppercased())
                        .font(.system(size: UIScale.pt(9), weight: .semibold))
                        .tracking(UIScale.pt(0.5))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                    Text(ByteFormatter.string(usage.sizeBytes))
                        .font(.system(size: UIScale.pt(13), weight: .medium))
                        .foregroundStyle(DashSkin.ink(dark))
                    if usage.reclaimableBytes > 0 {
                        Text("\(ByteFormatter.string(usage.reclaimableBytes)) reclaimable")
                            .font(.system(size: UIScale.pt(10)))
                            .foregroundStyle(DashSkin.inkFaint(dark))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(UIScale.pt(12))
                .background(
                    DashSkin.paper2(dark), in: RoundedRectangle(cornerRadius: UIScale.pt(12)))
            }
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: UIScale.pt(12)))
            .foregroundStyle(DashSkin.inkFaint(dark))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, UIScale.pt(14))
    }

    private func notice(_ title: String, detail: String, symbol: String) -> some View {
        VStack(spacing: UIScale.pt(10)) {
            Image(systemName: symbol)
                .font(.system(size: UIScale.pt(30)))
                .foregroundStyle(DashSkin.inkFaint(dark))
            Text(title)
                .font(DashSkin.serif(18))
                .foregroundStyle(DashSkin.ink(dark))
            Text(detail)
                .font(.system(size: UIScale.pt(12)))
                .foregroundStyle(DashSkin.inkFaint(dark))
                .multilineTextAlignment(.center)
                .frame(maxWidth: UIScale.pt(420))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func perform(_ command: String, on id: String) {
        busyIDs.insert(id)
        error = nil
        Task {
            let result = await session.runDocker(command)
            busyIDs.remove(id)
            if case let .failure(failure) = result {
                error = failure.localizedDescription
            }
            await session.refreshImagesAndVolumes()
        }
    }
}

private struct ContainerRow: View {
    let container: DockerContainer
    let dark: Bool
    let busy: Bool
    let onAction: (String) -> Void
    let onRemove: () -> Void
    let onLogs: () -> Void
    let onShell: () -> Void
    @State private var hovering = false

    private var stateColor: Color {
        switch container.state {
        case .running: return container.health == .unhealthy ? DashSkin.warn : DashSkin.ok
        case .paused, .restarting: return DashSkin.gold
        case .exited, .dead: return DashSkin.inkFaint(dark)
        default: return DashSkin.inkFaint(dark)
        }
    }

    var body: some View {
        HStack(spacing: UIScale.pt(10)) {
            Circle()
                .fill(stateColor)
                .frame(width: UIScale.pt(8), height: UIScale.pt(8))
            VStack(alignment: .leading, spacing: UIScale.pt(1)) {
                Text(container.composeService ?? container.displayName)
                    .font(.system(size: UIScale.pt(12.5), weight: .medium))
                    .foregroundStyle(DashSkin.ink(dark))
                    .lineLimit(1)
                Text("\(container.image)  ·  \(container.status)")
                    .font(DashSkin.mono(10))
                    .foregroundStyle(DashSkin.inkFaint(dark))
                    .lineLimit(1)
            }
            Spacer(minLength: UIScale.pt(8))
            if !container.ports.isEmpty {
                HStack(spacing: UIScale.pt(4)) {
                    ForEach(container.ports.prefix(2), id: \.self) { port in
                        if let url = port.browserURL {
                            Button {
                                NSWorkspace.shared.open(url)
                            } label: {
                                Text(port.displayName)
                                    .font(DashSkin.mono(9.5))
                                    .padding(.horizontal, UIScale.pt(5))
                                    .padding(.vertical, UIScale.pt(2))
                                    .background(
                                        DashSkin.accent(dark).opacity(0.15), in: Capsule()
                                    )
                                    .foregroundStyle(DashSkin.accent(dark))
                            }
                            .buttonStyle(.plain)
                            .pointerCursor()
                            .help("Open http://localhost:\(port.hostPort ?? 0)")
                        } else {
                            Text(port.displayName)
                                .font(DashSkin.mono(9.5))
                                .padding(.horizontal, UIScale.pt(5))
                                .padding(.vertical, UIScale.pt(2))
                                .background(DashSkin.line(dark), in: Capsule())
                                .foregroundStyle(DashSkin.inkFaint(dark))
                        }
                    }
                }
            }
            if let cpu = container.cpuPercent {
                Text(String(format: "%.1f%%", cpu))
                    .font(DashSkin.mono(11))
                    .foregroundStyle(DashSkin.inkSoft(dark))
                    .frame(width: UIScale.pt(52), alignment: .trailing)
            }
            if let memory = container.memUsedBytes {
                Text(ByteFormatter.string(memory))
                    .font(DashSkin.mono(11))
                    .foregroundStyle(DashSkin.inkSoft(dark))
                    .frame(width: UIScale.pt(66), alignment: .trailing)
            }
            actions
        }
        .padding(.vertical, UIScale.pt(7))
        .padding(.horizontal, UIScale.pt(4))
        .background(
            RoundedRectangle(cornerRadius: UIScale.pt(7))
                .fill(hovering ? DashSkin.inkFaint(dark).opacity(0.07) : .clear)
        )
        .onHover { hovering = $0 }
    }

    private var actions: some View {
        HStack(spacing: UIScale.pt(2)) {
            if busy {
                ProgressView().controlSize(.small).scaleEffect(0.6)
                    .frame(width: UIScale.pt(26))
            } else {
                Button {
                    onAction(container.state.isRunning ? "stop" : "start")
                } label: {
                    Image(systemName: container.state.isRunning ? "stop.fill" : "play.fill")
                }
                .buttonStyle(HoverButtonStyle())
                .help(container.state.isRunning ? "Stop" : "Start")
            }
            Button {
                onAction("restart")
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(HoverButtonStyle())
            .help("Restart")
            Button(action: onLogs) { Image(systemName: "text.alignleft") }
                .buttonStyle(HoverButtonStyle())
                .help("Logs")
            Button(action: onShell) { Image(systemName: "terminal") }
                .buttonStyle(HoverButtonStyle())
                .disabled(!container.state.isRunning)
                .help("Shell into container")
            Menu {
                Button(container.state == .paused ? "Unpause" : "Pause") {
                    onAction(container.state == .paused ? "unpause" : "pause")
                }
                Button("Copy container ID") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(container.id, forType: .string)
                }
                Divider()
                Button("Remove", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: UIScale.pt(24))
        }
        .font(.system(size: UIScale.pt(11)))
    }
}

private struct DockerLogsSheet: View {
    @ObservedObject var session: MachineSession
    let container: DockerContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var lines: [DockerLogLine] = []
    @State private var stream: SSHLineStream?
    @State private var follow = true
    @State private var showTimestamps = false
    @State private var filter = ""

    private var dark: Bool { scheme == .dark }

    private var visibleLines: [DockerLogLine] {
        let trimmed = filter.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return lines }
        return lines.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: UIScale.pt(10)) {
                Text(container.displayName)
                    .font(DashSkin.serif(17))
                    .foregroundStyle(DashSkin.ink(dark))
                Spacer()
                SearchField(placeholder: "Find", text: $filter)
                    .frame(width: UIScale.pt(180))
                Toggle("Timestamps", isOn: $showTimestamps)
                    .toggleStyle(.checkbox)
                    .font(.system(size: UIScale.pt(11)))
                Toggle("Follow", isOn: $follow)
                    .toggleStyle(.checkbox)
                    .font(.system(size: UIScale.pt(11)))
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        visibleLines.map(\.text).joined(separator: "\n"), forType: .string)
                }
                .pointerCursor()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .pointerCursor()
            }
            .padding(UIScale.pt(14))
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UIScale.pt(1)) {
                        ForEach(visibleLines) { line in
                            HStack(alignment: .top, spacing: UIScale.pt(8)) {
                                if showTimestamps, let timestamp = line.timestamp {
                                    Text(timestamp)
                                        .font(DashSkin.mono(9.5))
                                        .foregroundStyle(DashSkin.inkFaint(dark))
                                        .frame(width: UIScale.pt(160), alignment: .leading)
                                }
                                Text(line.text)
                                    .font(DashSkin.mono(11))
                                    .foregroundStyle(
                                        line.isStderr ? DashSkin.warn : DashSkin.inkSoft(dark)
                                    )
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id(line.id)
                        }
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(UIScale.pt(12))
                }
                .onChange(of: lines.count) { _, _ in
                    guard follow else { return }
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }
            .background(DashSkin.paper(dark))
        }
        .frame(width: UIScale.pt(760), height: UIScale.pt(560))
        .onAppear(perform: startStream)
        .onDisappear { stream?.cancel() }
    }

    private func startStream() {
        guard let connection = session.connectionRef else { return }
        let command = DockerCommands.logs(container.id, tail: 300, follow: true)
        let process = connection.streamProcess(command: command)
        let logStream = SSHLineStream(
            process: process,
            onLine: { text, isStderr in
                Task { @MainActor in
                    let line = DockerParsing.splitLogLine(
                        text, index: lines.count, isStderr: isStderr)
                    lines.append(line)
                    if lines.count > 5000 { lines.removeFirst(lines.count - 5000) }
                }
            },
            onExit: { _ in })
        try? logStream.start()
        stream = logStream
    }
}
