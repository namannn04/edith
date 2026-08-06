import EdithKit
import SwiftUI

struct MachinesPage: View {
    @StateObject private var model = MachinesModel.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.compactLayout) private var compact
    @State private var tab = MachineTab.overview
    @State private var addSheetPresented = false
    @State private var editingMachine: Machine?
    @State private var confirmRemoval: Machine?

    private var dark: Bool { scheme == .dark }

    var body: some View {
        VStack(spacing: UIScale.pt(0)) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DashSkin.paper(dark))
        .sheet(isPresented: $addSheetPresented) {
            AddMachineSheet { machine, secret in
                model.add(machine)
                if let secret { store(secret, for: machine) }
            }
        }
        .sheet(item: $editingMachine) { machine in
            AddMachineSheet(editing: machine) { updated, secret in
                model.update(updated)
                if let secret { store(secret, for: updated) }
            }
        }
        .confirmationDialog(
            "Remove \(confirmRemoval?.name ?? "machine")?",
            isPresented: Binding(
                get: { confirmRemoval != nil }, set: { if !$0 { confirmRemoval = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let machine = confirmRemoval { model.remove(id: machine.id) }
                confirmRemoval = nil
            }
            Button("Cancel", role: .cancel) { confirmRemoval = nil }
        } message: {
            Text(
                "Edith forgets the connection details and any saved password. Nothing on the machine changes."
            )
        }
        .onAppear {
            model.ensureSelection()
            model.startSelected()
        }
        .onChange(of: model.selection) { _, _ in
            model.startSelected()
            let available = MachineTab.tabs(isLocal: isLocalSelection)
            if !available.contains(tab) { tab = .overview }
        }
    }

    private var isLocalSelection: Bool {
        model.selection.map { model.isLocal($0) } ?? true
    }

    private var header: some View {
        PageHeader(
            "Machines",
            trailing: {
                Button {
                    addSheetPresented = true
                } label: {
                    Label("Add machine", systemImage: "plus")
                }
                .pointerCursor()
            },
            accessory: { machineStrip })
    }

    private var machineStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UIScale.pt(10)) {
                ForEach(model.allMachines) { machine in
                    MachineChip(
                        machine: machine,
                        session: model.session(for: machine.id),
                        selected: model.selection == machine.id,
                        isLocal: model.isLocal(machine.id), dark: dark
                    ) {
                        model.selection = machine.id
                    } onEdit: {
                        editingMachine = machine
                    } onRemove: {
                        confirmRemoval = machine
                    }
                }
            }
            .padding(.vertical, UIScale.pt(2))
        }
    }

    @ViewBuilder
    private var content: some View {
        if let session = model.selectedSession() {
            VStack(spacing: UIScale.pt(0)) {
                tabBar(session)
                Divider().opacity(0.35)
                detail(session)
            }
        } else {
            emptyState
        }
    }

    private func tabBar(_ session: MachineSession) -> some View {
        HStack(spacing: UIScale.pt(4)) {
            ForEach(MachineTab.tabs(isLocal: session.isLocal)) { item in
                Button {
                    tab = item
                } label: {
                    HStack(spacing: UIScale.pt(6)) {
                        Image(systemName: item.icon)
                            .font(.system(size: UIScale.pt(11), weight: .medium))
                        Text(item.title)
                            .font(.system(size: UIScale.pt(12.5), weight: .medium))
                    }
                    .padding(.horizontal, UIScale.pt(11))
                    .padding(.vertical, UIScale.pt(6))
                    .foregroundStyle(
                        tab == item ? DashSkin.ink(dark) : DashSkin.inkFaint(dark)
                    )
                    .background(
                        tab == item ? DashSkin.paper2(dark) : .clear,
                        in: RoundedRectangle(cornerRadius: UIScale.pt(8))
                    )
                    .overlay {
                        if tab == item {
                            RoundedRectangle(cornerRadius: UIScale.pt(8))
                                .strokeBorder(DashSkin.line(dark))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
            Spacer(minLength: 0)
            ConnectionPill(session: session, dark: dark)
        }
        .padding(.horizontal, PageMetrics.gutter(compact))
        .padding(.bottom, UIScale.pt(10))
    }

    @ViewBuilder
    private func detail(_ session: MachineSession) -> some View {
        switch tab {
        case .overview: MachineOverviewTab(session: session)
        case .processes: MachineProcessesTab(session: session)
        case .files: MachineFilesTab(session: session)
        case .docker: MachineDockerTab(session: session)
        case .terminal: MachineTerminalTab(session: session)
        case .tools: MachineToolsTab(session: session, model: model)
        }
    }

    private var emptyState: some View {
        VStack(spacing: UIScale.pt(12)) {
            Image(systemName: "server.rack")
                .font(.system(size: UIScale.pt(38)))
                .foregroundStyle(DashSkin.inkFaint(dark))
            Text("No machines yet")
                .font(DashSkin.serif(20))
                .foregroundStyle(DashSkin.ink(dark))
            Text(
                "Add a computer you can reach over SSH to watch its resources, browse its files, and run its containers."
            )
            .font(.system(size: UIScale.pt(12.5)))
            .foregroundStyle(DashSkin.inkFaint(dark))
            .multilineTextAlignment(.center)
            .frame(maxWidth: UIScale.pt(420))
            Button("Add machine") { addSheetPresented = true }
                .pointerCursor()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func store(_ secret: String, for machine: Machine) {
        let kind: MachineSecretKind = machine.auth == .password ? .password : .passphrase
        MachineSecrets.set(secret, machineID: machine.id, kind: kind)
    }
}

private struct MachineChip: View {
    let machine: Machine
    @ObservedObject var session: MachineSession
    let selected: Bool
    let isLocal: Bool
    let dark: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: UIScale.pt(8)) {
                Image(systemName: isLocal ? "laptopcomputer" : "server.rack")
                    .font(.system(size: UIScale.pt(13)))
                    .foregroundStyle(selected ? DashSkin.accent(dark) : DashSkin.inkSoft(dark))
                VStack(alignment: .leading, spacing: UIScale.pt(1)) {
                    Text(machine.name)
                        .font(.system(size: UIScale.pt(12.5), weight: .medium))
                        .foregroundStyle(DashSkin.ink(dark))
                        .lineLimit(1)
                    Text(isLocal ? "Local" : machine.subtitle)
                        .font(.system(size: UIScale.pt(10.5)))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                        .lineLimit(1)
                }
                Circle()
                    .fill(MachineStatusStyle.color(session.state, dark: dark))
                    .frame(width: UIScale.pt(7), height: UIScale.pt(7))
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
        .contextMenu {
            if !isLocal {
                Button("Edit…", action: onEdit)
                Button(session.state.isConnected ? "Disconnect" : "Connect") {
                    session.state.isConnected ? session.stop() : session.start()
                }
                Divider()
                Button("Remove", role: .destructive, action: onRemove)
            }
        }
    }
}

private struct ConnectionPill: View {
    @ObservedObject var session: MachineSession
    let dark: Bool

    var body: some View {
        HStack(spacing: UIScale.pt(6)) {
            if session.state.isBusy {
                ProgressView().controlSize(.small).scaleEffect(0.7)
            } else {
                Circle()
                    .fill(MachineStatusStyle.color(session.state, dark: dark))
                    .frame(width: UIScale.pt(7), height: UIScale.pt(7))
            }
            Text(MachineStatusStyle.label(session.state))
                .font(.system(size: UIScale.pt(11)))
                .foregroundStyle(DashSkin.inkFaint(dark))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: UIScale.pt(260), alignment: .trailing)
            if case .failed = session.state {
                Button("Retry") { session.retry() }
                    .buttonStyle(.plain)
                    .font(.system(size: UIScale.pt(11), weight: .semibold))
                    .foregroundStyle(DashSkin.accent(dark))
                    .pointerCursor()
            }
        }
    }
}
