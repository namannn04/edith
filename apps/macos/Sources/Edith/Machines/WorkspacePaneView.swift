import AppKit
import EdithKit
import SwiftUI

@MainActor
final class PaneViewStore: ObservableObject {
    static let shared = PaneViewStore()

    private var finders: [UUID: FinderModel] = [:]
    private var terminals: [UUID: TerminalSessionHolder] = [:]

    private init() {}

    func finder(for tabID: UUID, session: MachineSession) -> FinderModel {
        if let existing = finders[tabID], existing.session.id == session.id { return existing }
        let model = FinderModel(session: session)
        finders[tabID] = model
        return model
    }

    func terminal(for tabID: UUID) -> TerminalSessionHolder {
        if let existing = terminals[tabID] { return existing }
        let holder = TerminalSessionHolder()
        terminals[tabID] = holder
        return holder
    }

    func release(tabID: UUID) {
        finders.removeValue(forKey: tabID)
        terminals.removeValue(forKey: tabID)?.stop()
    }
}

struct PaneContentView: View {
    @ObservedObject var session: MachineSession
    @ObservedObject var machines: MachinesModel
    let screen: PaneScreen
    let tabID: UUID

    var body: some View {
        switch screen {
        case .overview: MachineOverviewTab(session: session)
        case .processes: MachineProcessesTab(session: session)
        case .docker: MachineDockerTab(session: session)
        case .terminal:
            MachineTerminalTab(session: session, holder: PaneViewStore.shared.terminal(for: tabID))
        case .files:
            FinderPane(model: PaneViewStore.shared.finder(for: tabID, session: session))
        case .tools: MachineToolsTab(session: session, model: machines)
        }
    }
}

struct WorkspacePaneView: View {
    let pane: PaneNode
    @ObservedObject var model: WorkspaceModel
    @ObservedObject var machines: MachinesModel
    let dark: Bool

    private var focused: Bool { model.layout.focused == pane.id }

    private var selectedTab: PaneTab? {
        pane.tabs.first { $0.id == pane.selected } ?? pane.tabs.first
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider().opacity(0.3)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DashSkin.paper(dark))
        .overlay {
            RoundedRectangle(cornerRadius: UIScale.pt(6))
                .strokeBorder(
                    focused ? DashSkin.accent(dark).opacity(0.55) : DashSkin.line(dark),
                    lineWidth: UIScale.pt(focused ? 1.5 : 1))
        }
        .contentShape(Rectangle())
        .onTapGesture { model.apply { $0.focused = pane.id } }
    }

    @ViewBuilder
    private var content: some View {
        if let tab = selectedTab {
            let session = machines.session(for: tab.target.machineID)
            PaneContentView(
                session: session, machines: machines, screen: tab.target.screen, tabID: tab.id)
        } else {
            Color.clear
        }
    }

    private var tabStrip: some View {
        HStack(spacing: UIScale.pt(3)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UIScale.pt(3)) {
                    ForEach(pane.tabs) { tab in
                        tabChip(tab)
                    }
                }
            }
            Menu {
                ForEach(machines.allMachines) { machine in
                    Menu(machine.name) {
                        ForEach(
                            PaneScreen.available(isLocal: machines.isLocal(machine.id)),
                            id: \.self
                        ) { screen in
                            Button(screen.title) {
                                model.addTab(
                                    to: pane.id,
                                    target: PaneTarget(machineID: machine.id, screen: screen))
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Add a view to this pane")

            Menu {
                Button("Split Right") { split(.right) }
                Button("Split Down") { split(.bottom) }
                Divider()
                Button("Close Pane") { model.apply { $0.closePane(pane.id) } }
                    .disabled(model.layout.paneCount < 2)
            } label: {
                Image(systemName: "square.split.2x1")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Split or close this pane")
        }
        .padding(.horizontal, UIScale.pt(6))
        .padding(.vertical, UIScale.pt(4))
        .background(.thinMaterial)
    }

    private func split(_ side: InsertSide) {
        guard let target = selectedTab?.target else { return }
        model.apply { $0.split(paneID: pane.id, side: side, target: target) }
    }

    private func tabChip(_ tab: PaneTab) -> some View {
        let machine = machines.allMachines.first { $0.id == tab.target.machineID }
        let session = machines.session(for: tab.target.machineID)
        let selected = tab.id == pane.selected
        return Button {
            model.apply { layout in
                layout.focused = pane.id
                layout.root.updatePane(pane.id) { $0.selected = tab.id }
            }
        } label: {
            HStack(spacing: UIScale.pt(5)) {
                Circle()
                    .fill(MachineStatusStyle.color(session.state, dark: dark))
                    .frame(width: UIScale.pt(5), height: UIScale.pt(5))
                Image(systemName: tab.target.screen.icon)
                    .font(.system(size: UIScale.pt(9.5)))
                Text("\(machine?.name ?? "Machine") · \(tab.target.screen.title)")
                    .font(.system(size: UIScale.pt(11), weight: .medium))
                    .lineLimit(1)
                if pane.tabs.count > 1 {
                    Button {
                        model.closeTab(tab.id, in: pane.id)
                        PaneViewStore.shared.release(tabID: tab.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: UIScale.pt(7.5), weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(selected ? DashSkin.ink(dark) : DashSkin.inkFaint(dark))
            .padding(.horizontal, UIScale.pt(8))
            .padding(.vertical, UIScale.pt(4))
            .background(
                selected ? DashSkin.paper2(dark) : .clear,
                in: RoundedRectangle(cornerRadius: UIScale.pt(6))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .contextMenu {
            ForEach(machines.allMachines) { machine in
                Menu(machine.name) {
                    ForEach(
                        PaneScreen.available(isLocal: machines.isLocal(machine.id)), id: \.self
                    ) { screen in
                        Button(screen.title) {
                            model.retargetPane(
                                pane.id, tabID: tab.id,
                                to: PaneTarget(machineID: machine.id, screen: screen))
                        }
                    }
                }
            }
        }
    }
}
