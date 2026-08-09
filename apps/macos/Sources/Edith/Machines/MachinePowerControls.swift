import EdithKit
import SwiftUI

struct MachinePowerControls: View {
    @ObservedObject var session: MachineSession
    @ObservedObject var model: MachinesModel
    let dark: Bool

    @State private var confirmPower: String?
    @State private var message: String?
    @State private var showingMessage = false

    private var wakeAddress: String? {
        session.machine.wakeMACAddress ?? session.facts.macAddress
    }

    var body: some View {
        HStack(spacing: UIScale.pt(2)) {
            Button {
                confirmPower = "reboot"
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(HoverButtonStyle())
            .disabled(!session.state.isConnected)
            .help("Restart this machine")

            Button {
                confirmPower = "poweroff"
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(HoverButtonStyle())
            .disabled(!session.state.isConnected)
            .help("Shut this machine down")

            Button {
                announce(model.wake(machine: session.machine))
            } label: {
                Image(systemName: "bolt")
            }
            .buttonStyle(HoverButtonStyle())
            .disabled(wakeAddress == nil)
            .help(wakeAddress.map { "Wake this machine (\($0))" } ?? "No wake address known")
        }
        .font(.system(size: UIScale.pt(11)))
        .popover(isPresented: $showingMessage, arrowEdge: .bottom) {
            Text(message ?? "")
                .font(.system(size: UIScale.pt(11.5)))
                .foregroundStyle(DashSkin.ink(dark))
                .padding(UIScale.pt(10))
                .frame(maxWidth: UIScale.pt(280))
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
        .onChange(of: session.facts.macAddress) { _, mac in
            guard let mac, session.machine.wakeMACAddress == nil else { return }
            var updated = session.machine
            updated.wakeMACAddress = mac
            model.store.update(updated)
        }
    }

    private func announce(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        message = text
        showingMessage = true
        Task {
            try? await Task.sleep(for: .seconds(4))
            showingMessage = false
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
                announce(underway)
                session.stop()
            case let .failure(error):
                guard PowerOutcome.hostWentAway(error) else {
                    announce(PowerOutcome.explain(error))
                    return
                }
                announce(underway)
                session.stop()
            }
        }
    }
}
