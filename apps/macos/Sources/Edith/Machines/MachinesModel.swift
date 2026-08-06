import AppKit
import EdithKit
import SwiftUI

@MainActor
final class MachinesModel: ObservableObject {
    static let shared = MachinesModel()

    @Published private(set) var store = MachineStore()
    @Published private(set) var sessions: [UUID: MachineSession] = [:]
    @Published var selection: UUID?

    static let localMachineID = UUID(uuidString: "00000000-0000-0000-0000-0000000000ED")!

    let localMachine = Machine(
        id: MachinesModel.localMachineID, name: "This Mac", host: "localhost",
        source: .manual, createdAt: Date(timeIntervalSince1970: 0))

    private init() {
        MachinePaths.prepare()
    }

    var allMachines: [Machine] {
        [localMachine] + store.machines
    }

    func isLocal(_ id: UUID) -> Bool { id == Self.localMachineID }

    func session(for id: UUID) -> MachineSession {
        if let existing = sessions[id] { return existing }
        let machine = id == Self.localMachineID ? localMachine : store.machine(id: id)
        let session = MachineSession(
            machine: machine ?? localMachine, local: id == Self.localMachineID)
        sessions[id] = session
        return session
    }

    func selectedSession() -> MachineSession? {
        guard let selection else { return nil }
        return session(for: selection)
    }

    func ensureSelection() {
        if let selection, allMachines.contains(where: { $0.id == selection }) { return }
        selection = allMachines.first?.id
    }

    func restoreSelection(_ stored: String) {
        if selection == nil, let id = UUID(uuidString: stored),
            allMachines.contains(where: { $0.id == id })
        {
            selection = id
        }
        ensureSelection()
    }

    func add(_ machine: Machine) {
        store.add(machine)
        selection = machine.id
        session(for: machine.id).start()
    }

    func update(_ machine: Machine) {
        store.update(machine)
        if let session = sessions[machine.id] {
            session.stop()
            sessions[machine.id] = nil
        }
        _ = session(for: machine.id)
    }

    func remove(id: UUID) {
        sessions[id]?.stop()
        sessions[id] = nil
        store.remove(id: id)
        ensureSelection()
    }

    func startSelected() {
        guard let selection else { return }
        let session = session(for: selection)
        if case .disconnected = session.state {
            session.start()
        }
    }

    func stopAll() {
        for session in sessions.values { session.stop() }
        sessions = [:]
    }

    func addForward(_ forward: PortForward) {
        store.addForward(forward)
    }

    func removeForward(_ forward: PortForward) {
        Task { await session(for: forward.machineID).setForward(forward, active: false) }
        store.removeForward(id: forward.id)
    }

    func addSnippet(_ snippet: CommandSnippet) {
        store.addSnippet(snippet)
    }

    func removeSnippet(_ snippet: CommandSnippet) {
        store.removeSnippet(id: snippet.id)
    }

    func wake(machine: Machine) -> String {
        guard let mac = machine.wakeMACAddress,
            let packet = WakeOnLAN.magicPacket(macAddress: mac)
        else {
            return "No MAC address stored for this machine yet."
        }
        return MagicPacketSender.send(packet) ?? "Sent a wake packet to \(mac)."
    }
}

enum MagicPacketSender {
    static func send(_ packet: Data) -> String? {
        let handle = socket(AF_INET, SOCK_DGRAM, 0)
        guard handle >= 0 else { return "Could not open a socket." }
        defer { close(handle) }
        var broadcast: Int32 = 1
        setsockopt(
            handle, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(9).bigEndian
        address.sin_addr.s_addr = INADDR_BROADCAST
        let sent = packet.withUnsafeBytes { buffer -> Int in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    sendto(
                        handle, buffer.baseAddress, buffer.count, 0, sockaddrPointer,
                        socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        return sent > 0 ? nil : "The wake packet could not be sent."
    }
}

enum MachineTab: String, CaseIterable, Identifiable {
    case overview
    case processes
    case docker
    case terminal
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .processes: return "Processes"
        case .docker: return "Docker"
        case .terminal: return "Terminal"
        case .tools: return "Tools"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "gauge.with.needle"
        case .processes: return "list.bullet.rectangle"
        case .docker: return "shippingbox"
        case .terminal: return "terminal"
        case .tools: return "wrench.and.screwdriver"
        }
    }

    static func tabs(isLocal: Bool) -> [MachineTab] {
        isLocal ? [.overview, .processes, .terminal] : MachineTab.allCases
    }
}

enum MachineStatusStyle {
    static func color(_ state: MachineConnectionState, dark: Bool) -> Color {
        switch state {
        case .connected(let latency):
            guard let latency else { return DashSkin.ok }
            if latency > 400 { return DashSkin.warn }
            return DashSkin.ok
        case .connecting: return DashSkin.gold
        case .disconnected: return DashSkin.inkFaint(dark)
        case .failed: return DashSkin.danger
        }
    }

    static func label(_ state: MachineConnectionState) -> String {
        switch state {
        case let .connected(latency):
            guard let latency else { return "Connected" }
            return String(format: "%.0f ms", latency)
        case .connecting: return "Connecting…"
        case .disconnected: return "Not connected"
        case let .failed(message): return message
        }
    }
}
