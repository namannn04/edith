import AppKit
import EdithKit
import SwiftUI

struct MachineToolsTab: View {
    @ObservedObject var session: MachineSession
    @ObservedObject var model: MachinesModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.compactLayout) private var compact
    @State private var newForwardLocal = ""
    @State private var newForwardRemote = ""
    @State private var newForwardHost = "localhost"
    @State private var snippetTitle = ""
    @State private var snippetCommand = ""
    @State private var snippetOutput = ""
    @State private var runningSnippet = false
    @State private var message: String?
    @State private var confirmPower: String?
    @State private var serviceFilter = ""

    private var dark: Bool { scheme == .dark }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIScale.pt(16)) {
                if let message {
                    Text(message)
                        .font(.system(size: UIScale.pt(11.5)))
                        .foregroundStyle(DashSkin.inkSoft(dark))
                        .padding(UIScale.pt(10))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            DashSkin.accent(dark).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: UIScale.pt(9)))
                }
                forwardsCard
                snippetsCard
                servicesCard
                powerCard
            }
            .pageContent(compact)
        }
        .confirmationDialog(
            confirmPower == "reboot" ? "Restart this machine?" : "Shut this machine down?",
            isPresented: Binding(
                get: { confirmPower != nil }, set: { if !$0 { confirmPower = nil } }),
            titleVisibility: .visible
        ) {
            Button(confirmPower == "reboot" ? "Restart" : "Shut down", role: .destructive) {
                runPower(confirmPower ?? "")
                confirmPower = nil
            }
            Button("Cancel", role: .cancel) { confirmPower = nil }
        } message: {
            Text("The SSH connection drops immediately. Edith reconnects when it comes back.")
        }
        .task {
            await session.refreshServices()
        }
    }

    private var forwardsCard: some View {
        SkinCard(
            title: "Port forwards",
            note: "Reach a service on this machine at localhost on your Mac", dark: dark
        ) {
            VStack(alignment: .leading, spacing: UIScale.pt(10)) {
                ForEach(model.store.forwards(machineID: session.machine.id)) { forward in
                    HStack(spacing: UIScale.pt(10)) {
                        Circle()
                            .fill(
                                session.activeForwards.contains(forward.id)
                                    ? DashSkin.ok : DashSkin.inkFaint(dark)
                            )
                            .frame(width: UIScale.pt(7), height: UIScale.pt(7))
                        Text(forward.displayName)
                            .font(DashSkin.mono(11.5))
                            .foregroundStyle(DashSkin.ink(dark))
                        Spacer(minLength: 0)
                        if session.activeForwards.contains(forward.id) {
                            Button("Open") {
                                if let url = URL(string: "http://localhost:\(forward.localPort)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .pointerCursor()
                            .font(.system(size: UIScale.pt(11)))
                        }
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { session.activeForwards.contains(forward.id) },
                                set: { toggleForward(forward, on: $0) })
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .disabled(!session.state.isConnected)
                        Button {
                            model.removeForward(forward)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(HoverButtonStyle())
                        .help("Remove")
                    }
                }
                HStack(spacing: UIScale.pt(8)) {
                    TextField("Local port", text: $newForwardLocal)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: UIScale.pt(90))
                    Image(systemName: "arrow.right")
                        .font(.system(size: UIScale.pt(10)))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                    TextField("Remote host", text: $newForwardHost)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: UIScale.pt(130))
                    TextField("Remote port", text: $newForwardRemote)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: UIScale.pt(90))
                    Button("Add") { addForward() }
                        .disabled(Int(newForwardLocal) == nil || Int(newForwardRemote) == nil)
                        .pointerCursor()
                }
            }
        }
    }

    private var snippetsCard: some View {
        SkinCard(title: "Snippets", note: "Saved commands you run often", dark: dark) {
            VStack(alignment: .leading, spacing: UIScale.pt(10)) {
                ForEach(model.store.snippets(machineID: session.machine.id)) { snippet in
                    HStack(spacing: UIScale.pt(10)) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(snippet.title)
                                .font(.system(size: UIScale.pt(12.5), weight: .medium))
                                .foregroundStyle(DashSkin.ink(dark))
                            Text(snippet.command)
                                .font(DashSkin.mono(10))
                                .foregroundStyle(DashSkin.inkFaint(dark))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Button("Run") { run(snippet.command) }
                            .disabled(runningSnippet || !session.state.isConnected)
                            .pointerCursor()
                            .font(.system(size: UIScale.pt(11)))
                        Button {
                            model.removeSnippet(snippet)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(HoverButtonStyle())
                        .help("Remove")
                    }
                }
                HStack(spacing: UIScale.pt(8)) {
                    TextField("Name", text: $snippetTitle)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: UIScale.pt(140))
                    TextField("Command", text: $snippetCommand)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") { saveSnippet() }
                        .disabled(
                            snippetTitle.trimmingCharacters(in: .whitespaces).isEmpty
                                || snippetCommand.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                        .pointerCursor()
                }
                if !snippetOutput.isEmpty {
                    TerminalLogView(
                        log: snippetOutput, theme: DashSkin.sage, height: UIScale.pt(160))
                }
            }
        }
    }

    private var filteredServices: [SystemdService] {
        let trimmed = serviceFilter.trimmingCharacters(in: .whitespaces)
        let base = session.services
        guard !trimmed.isEmpty else { return Array(base.prefix(40)) }
        return base.filter { $0.unit.localizedCaseInsensitiveContains(trimmed) }
    }

    private var servicesCard: some View {
        SkinCard(
            title: "Services", note: session.services.isEmpty ? "systemd not detected" : nil,
            dark: dark
        ) {
            VStack(alignment: .leading, spacing: UIScale.pt(8)) {
                if !session.services.isEmpty {
                    SearchField(placeholder: "Filter services", text: $serviceFilter)
                        .frame(maxWidth: UIScale.pt(240))
                }
                ForEach(filteredServices) { service in
                    HStack(spacing: UIScale.pt(10)) {
                        Circle()
                            .fill(
                                service.isFailed
                                    ? DashSkin.danger
                                    : (service.isRunning ? DashSkin.ok : DashSkin.inkFaint(dark))
                            )
                            .frame(width: UIScale.pt(7), height: UIScale.pt(7))
                        Text(service.displayName)
                            .font(.system(size: UIScale.pt(12)))
                            .foregroundStyle(DashSkin.ink(dark))
                            .lineLimit(1)
                        Text(service.describes)
                            .font(.system(size: UIScale.pt(10.5)))
                            .foregroundStyle(DashSkin.inkFaint(dark))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Button("Restart") { runService("restart", unit: service.unit) }
                            .pointerCursor()
                            .font(.system(size: UIScale.pt(11)))
                        Button(service.isRunning ? "Stop" : "Start") {
                            runService(service.isRunning ? "stop" : "start", unit: service.unit)
                        }
                        .pointerCursor()
                        .font(.system(size: UIScale.pt(11)))
                    }
                }
            }
        }
    }

    private var powerCard: some View {
        SkinCard(title: "Power", dark: dark) {
            HStack(spacing: UIScale.pt(10)) {
                Button("Restart…") { confirmPower = "reboot" }
                    .disabled(!session.state.isConnected)
                    .pointerCursor()
                Button("Shut down…") { confirmPower = "poweroff" }
                    .disabled(!session.state.isConnected)
                    .pointerCursor()
                Button("Wake") {
                    message = model.wake(machine: session.machine)
                }
                .disabled(session.machine.wakeMACAddress == nil && session.facts.macAddress == nil)
                .pointerCursor()
                Spacer(minLength: 0)
                if let mac = session.machine.wakeMACAddress ?? session.facts.macAddress {
                    Text(mac)
                        .font(DashSkin.mono(10.5))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                }
            }
        }
        .onChange(of: session.facts.macAddress) { _, mac in
            guard let mac, session.machine.wakeMACAddress == nil else { return }
            var updated = session.machine
            updated.wakeMACAddress = mac
            model.store.update(updated)
        }
    }

    private func addForward() {
        guard let local = Int(newForwardLocal), let remote = Int(newForwardRemote) else { return }
        let host = newForwardHost.trimmingCharacters(in: .whitespaces)
        let forward = PortForward(
            machineID: session.machine.id, localPort: local,
            remoteHost: host.isEmpty ? "localhost" : host, remotePort: remote)
        model.addForward(forward)
        newForwardLocal = ""
        newForwardRemote = ""
        toggleForward(forward, on: true)
    }

    private func toggleForward(_ forward: PortForward, on: Bool) {
        Task {
            if let failure = await session.setForward(forward, active: on) {
                message = failure
            } else {
                message =
                    on
                    ? "localhost:\(forward.localPort) now reaches "
                        + "\(forward.remoteHost):\(forward.remotePort)."
                    : nil
            }
        }
    }

    private func saveSnippet() {
        model.addSnippet(
            CommandSnippet(
                machineID: session.machine.id,
                title: snippetTitle.trimmingCharacters(in: .whitespaces),
                command: snippetCommand.trimmingCharacters(in: .whitespaces)))
        snippetTitle = ""
        snippetCommand = ""
    }

    private func run(_ command: String) {
        runningSnippet = true
        snippetOutput = "$ \(command)\n"
        Task {
            let result = await session.runCommand(command, timeout: 120)
            runningSnippet = false
            switch result {
            case let .success(output): snippetOutput += output
            case let .failure(error): snippetOutput += error.localizedDescription
            }
        }
    }

    private func runService(_ action: String, unit: String) {
        Task {
            let machineID = session.machine.id
            let stdin = SudoPassword.stdin(machineID: machineID)
            let result = await session.runCommand(
                ServiceCommands.action(action, unit: unit, withSudoPassword: stdin != nil),
                stdin: stdin, timeout: 60)
            if case let .failure(error) = result {
                message = PowerOutcome.explain(error)
            } else {
                message = "\(unit) \(action)ed."
            }
            await session.refreshServices()
        }
    }

    private func runPower(_ action: String) {
        Task {
            let stdin = SudoPassword.stdin(machineID: session.machine.id)
            let command =
                action == "reboot"
                ? ServiceCommands.reboot(withSudoPassword: stdin != nil)
                : ServiceCommands.shutdown(withSudoPassword: stdin != nil)
            let underway = action == "reboot" ? "Restarting…" : "Shutting down…"
            switch await session.runCommand(command, stdin: stdin, timeout: 20) {
            case .success:
                message = underway
                session.stop()
            case let .failure(error):
                guard PowerOutcome.hostWentAway(error) else {
                    message = PowerOutcome.explain(error)
                    return
                }
                message = underway
                session.stop()
            }
        }
    }
}
