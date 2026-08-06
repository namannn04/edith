import AppKit
import EdithKit
import SwiftUI

@MainActor
final class DockerDetailModel: ObservableObject {
    @Published var logs: [DockerLogLine] = []
    @Published var inspect: DockerInspectSummary?
    @Published var processes: [DockerProcess] = []
    @Published var files: [RemoteFileEntry] = []
    @Published var filePath = "/"
    @Published var cpuHistory: [Double] = []
    @Published var memHistory: [Double] = []
    @Published var follow = true
    @Published var showTimestamps = false
    @Published var logFilter = ""

    private var stream: SSHLineStream?

    var visibleLogs: [DockerLogLine] {
        let trimmed = logFilter.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return logs }
        return logs.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
    }

    func startLogs(session: MachineSession, container: DockerContainer) {
        stopLogs()
        guard let connection = session.connectionRef else { return }
        let process = connection.streamProcess(
            command: DockerCommands.logs(container.id, tail: 400, follow: true))
        let stream = SSHLineStream(
            process: process,
            onLine: { [weak self] text, isStderr in
                Task { @MainActor in
                    guard let self else { return }
                    let line = DockerParsing.splitLogLine(
                        text, index: self.logs.count, isStderr: isStderr)
                    self.logs.append(line)
                    if self.logs.count > 4000 {
                        self.logs.removeFirst(self.logs.count - 4000)
                    }
                }
            },
            onExit: { _ in })
        try? stream.start()
        self.stream = stream
    }

    func stopLogs() {
        stream?.cancel()
        stream = nil
    }

    func loadInspect(session: MachineSession, container: DockerContainer) async {
        let result = await session.runCommand(
            DockerCommands.inspectRaw(container.id), timeout: 30)
        guard case let .success(output) = result else { return }
        inspect = DockerParsing.inspectSummary(output)
    }

    func loadProcesses(session: MachineSession, container: DockerContainer) async {
        let result = await session.runCommand(DockerCommands.top(container.id), timeout: 30)
        guard case let .success(output) = result else { return }
        processes = DockerParsing.processes(output)
    }

    func loadFiles(session: MachineSession, container: DockerContainer, path: String) async {
        filePath = path
        let result = await session.runCommand(
            DockerCommands.listFiles(containerID: container.id, path: path), timeout: 30)
        guard case let .success(output) = result else {
            files = []
            return
        }
        files = FileListing.parse(output: output, parent: path)
    }

    func record(container: DockerContainer) {
        if let cpu = container.cpuPercent {
            cpuHistory = MachineSession.appending(cpu, to: cpuHistory)
        }
        if let used = container.memUsedBytes, let limit = container.memLimitBytes, limit > 0 {
            memHistory = MachineSession.appending(
                Double(used) / Double(limit) * 100, to: memHistory)
        }
    }
}

struct DockerContainerDetail: View {
    @ObservedObject var session: MachineSession
    let container: DockerContainer
    let dark: Bool
    let onBack: () -> Void
    let onAction: (String) -> Void
    let onShell: () -> Void
    let onRemove: () -> Void

    @StateObject private var model = DockerDetailModel()
    @State private var tab = DockerDetailTab.logs

    private var live: DockerContainer {
        session.containers.first { $0.id == container.id } ?? container
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            tabBar
            Divider().opacity(0.3)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: container.id) {
            model.startLogs(session: session, container: container)
            await model.loadInspect(session: session, container: container)
        }
        .onDisappear { model.stopLogs() }
        .onChange(of: session.containers) { _, _ in model.record(container: live) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: UIScale.pt(10)) {
            HStack(spacing: UIScale.pt(10)) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(HoverButtonStyle())
                .help("Back to the list")
                VStack(alignment: .leading, spacing: UIScale.pt(2)) {
                    Text(live.displayName)
                        .font(DashSkin.serif(20))
                        .foregroundStyle(DashSkin.ink(dark))
                    Text("\(live.image)  ·  \(live.shortID)")
                        .font(DashSkin.mono(10.5))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                }
                Spacer(minLength: 0)
                statusPill
            }
            HStack(spacing: UIScale.pt(8)) {
                Button(live.state.isRunning ? "Stop" : "Start") {
                    onAction(live.state.isRunning ? "stop" : "start")
                }
                Button("Restart") { onAction("restart") }
                Button(live.state == .paused ? "Unpause" : "Pause") {
                    onAction(live.state == .paused ? "unpause" : "pause")
                }
                Button("Shell", action: onShell).disabled(!live.state.isRunning)
                Spacer(minLength: 0)
                ForEach(live.ports.prefix(3), id: \.self) { port in
                    if let url = port.browserURL {
                        Button(port.displayName) { NSWorkspace.shared.open(url) }
                            .pointerCursor()
                    }
                }
                Button("Remove", role: .destructive, action: onRemove)
            }
            .font(.system(size: UIScale.pt(11.5)))
        }
        .padding(.horizontal, UIScale.pt(16))
        .padding(.vertical, UIScale.pt(12))
    }

    private var statusPill: some View {
        HStack(spacing: UIScale.pt(6)) {
            Circle()
                .fill(live.state.isRunning ? DashSkin.ok : DashSkin.inkFaint(dark))
                .frame(width: UIScale.pt(7), height: UIScale.pt(7))
            Text(live.status)
                .font(.system(size: UIScale.pt(11)))
                .foregroundStyle(DashSkin.inkSoft(dark))
        }
    }

    private var tabBar: some View {
        HStack(spacing: UIScale.pt(4)) {
            ForEach(DockerDetailTab.allCases) { item in
                Button {
                    tab = item
                    Task { await load(item) }
                } label: {
                    Text(item.title)
                        .font(.system(size: UIScale.pt(12), weight: .medium))
                        .padding(.horizontal, UIScale.pt(11))
                        .padding(.vertical, UIScale.pt(5))
                        .foregroundStyle(tab == item ? DashSkin.ink(dark) : DashSkin.inkFaint(dark))
                        .background(
                            tab == item ? DashSkin.paper2(dark) : .clear,
                            in: RoundedRectangle(cornerRadius: UIScale.pt(7))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
            Spacer(minLength: 0)
            if tab == .logs {
                SearchField(placeholder: "Find in logs", text: $model.logFilter)
                    .frame(width: UIScale.pt(180))
                Toggle("Timestamps", isOn: $model.showTimestamps)
                    .toggleStyle(.checkbox)
                    .font(.system(size: UIScale.pt(11)))
                Toggle("Follow", isOn: $model.follow)
                    .toggleStyle(.checkbox)
                    .font(.system(size: UIScale.pt(11)))
            }
        }
        .padding(.horizontal, UIScale.pt(16))
        .padding(.vertical, UIScale.pt(7))
    }

    private func load(_ item: DockerDetailTab) async {
        switch item {
        case .inspect: await model.loadInspect(session: session, container: container)
        case .processes: await model.loadProcesses(session: session, container: container)
        case .files: await model.loadFiles(session: session, container: container, path: "/")
        default: break
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .logs: logsView
        case .inspect: inspectView
        case .stats: statsView
        case .processes: processesView
        case .files: filesView
        }
    }

    private var logsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: UIScale.pt(1)) {
                    ForEach(model.visibleLogs) { line in
                        HStack(alignment: .top, spacing: UIScale.pt(8)) {
                            if model.showTimestamps, let timestamp = line.timestamp {
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
                .padding(UIScale.pt(14))
            }
            .onChange(of: model.logs.count) { _, _ in
                guard model.follow else { return }
                proxy.scrollTo("end", anchor: .bottom)
            }
        }
    }

    private var inspectView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIScale.pt(14)) {
                if let inspect = model.inspect {
                    section("Image", [inspect.image])
                    section("Command", [inspect.command])
                    section("Restart policy", [inspect.restartPolicy])
                    section("Networks", inspect.networks)
                    section("Mounts", inspect.mounts)
                    section("Environment", inspect.environment)
                    section(
                        "Labels", inspect.labels.sorted { $0.key < $1.key }.map { "\($0)=\($1)" })
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(UIScale.pt(16))
        }
    }

    private func section(_ title: String, _ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: UIScale.pt(4)) {
            Text(title.uppercased())
                .font(.system(size: UIScale.pt(9.5), weight: .semibold))
                .tracking(UIScale.pt(0.6))
                .foregroundStyle(DashSkin.inkFaint(dark))
            if values.filter({ !$0.isEmpty }).isEmpty {
                Text("—")
                    .font(DashSkin.mono(11))
                    .foregroundStyle(DashSkin.inkFaint(dark))
            }
            ForEach(values.filter { !$0.isEmpty }, id: \.self) { value in
                Text(value)
                    .font(DashSkin.mono(11))
                    .foregroundStyle(DashSkin.inkSoft(dark))
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsView: some View {
        VStack(alignment: .leading, spacing: UIScale.pt(16)) {
            statCard(
                "CPU", value: live.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—",
                history: model.cpuHistory, color: DashSkin.accent(dark))
            statCard(
                "Memory",
                value: live.memUsedBytes.map { ByteFormatter.string($0) } ?? "—",
                history: model.memHistory, color: DashSkin.sage)
            HStack(spacing: UIScale.pt(20)) {
                statItem("Network in", live.netRxBytes.map { ByteFormatter.string($0) } ?? "—")
                statItem("Network out", live.netTxBytes.map { ByteFormatter.string($0) } ?? "—")
                statItem(
                    "Memory limit", live.memLimitBytes.map { ByteFormatter.string($0) } ?? "—")
            }
            Spacer(minLength: 0)
        }
        .padding(UIScale.pt(16))
    }

    private func statCard(_ title: String, value: String, history: [Double], color: Color)
        -> some View
    {
        VStack(alignment: .leading, spacing: UIScale.pt(6)) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: UIScale.pt(9.5), weight: .semibold))
                    .foregroundStyle(DashSkin.inkFaint(dark))
                Spacer()
                Text(value)
                    .font(DashSkin.serif(18))
                    .foregroundStyle(DashSkin.ink(dark))
            }
            Sparkline(values: history, maximum: 100, color: color)
                .frame(height: UIScale.pt(54))
        }
        .padding(UIScale.pt(14))
        .background(DashSkin.paper2(dark), in: RoundedRectangle(cornerRadius: UIScale.pt(12)))
    }

    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: UIScale.pt(2)) {
            Text(label.uppercased())
                .font(.system(size: UIScale.pt(9), weight: .semibold))
                .foregroundStyle(DashSkin.inkFaint(dark))
            Text(value)
                .font(DashSkin.mono(12))
                .foregroundStyle(DashSkin.ink(dark))
        }
    }

    private var processesView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.processes) { process in
                    HStack(spacing: UIScale.pt(10)) {
                        Text(process.pid)
                            .font(DashSkin.mono(10.5))
                            .frame(width: UIScale.pt(56), alignment: .leading)
                        Text(process.user)
                            .font(.system(size: UIScale.pt(11)))
                            .frame(width: UIScale.pt(80), alignment: .leading)
                        Text(process.command)
                            .font(DashSkin.mono(10.5))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(process.cpu)
                            .font(DashSkin.mono(10.5))
                            .frame(width: UIScale.pt(50), alignment: .trailing)
                        Text(process.memory)
                            .font(DashSkin.mono(10.5))
                            .frame(width: UIScale.pt(50), alignment: .trailing)
                    }
                    .foregroundStyle(DashSkin.inkSoft(dark))
                    .padding(.horizontal, UIScale.pt(16))
                    .padding(.vertical, UIScale.pt(5))
                    Divider().opacity(0.15)
                }
            }
        }
    }

    private var filesView: some View {
        VStack(spacing: 0) {
            HStack(spacing: UIScale.pt(8)) {
                Button {
                    let parent = FileListing.parentPath(of: model.filePath) ?? "/"
                    Task {
                        await model.loadFiles(
                            session: session, container: container, path: parent)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(HoverButtonStyle())
                .disabled(model.filePath == "/")
                Text(model.filePath)
                    .font(DashSkin.mono(11))
                    .foregroundStyle(DashSkin.inkSoft(dark))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, UIScale.pt(16))
            .padding(.vertical, UIScale.pt(7))
            Divider().opacity(0.3)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.files) { entry in
                        HStack(spacing: UIScale.pt(10)) {
                            Image(systemName: entry.isDirectory ? "folder" : "doc")
                                .foregroundStyle(DashSkin.inkFaint(dark))
                                .frame(width: UIScale.pt(15))
                            Text(entry.name)
                                .font(.system(size: UIScale.pt(12)))
                                .foregroundStyle(DashSkin.ink(dark))
                            Spacer(minLength: 0)
                            if !entry.isDirectory {
                                Text(ByteFormatter.string(entry.sizeBytes))
                                    .font(DashSkin.mono(10))
                                    .foregroundStyle(DashSkin.inkFaint(dark))
                            }
                        }
                        .padding(.horizontal, UIScale.pt(16))
                        .padding(.vertical, UIScale.pt(5))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            guard entry.isDirectory else { return }
                            Task {
                                await model.loadFiles(
                                    session: session, container: container, path: entry.path)
                            }
                        }
                    }
                }
            }
        }
    }
}
