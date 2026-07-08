import AppKit
import EdithKit
import SwiftUI

@MainActor
final class PanelController: NSObject {
    static var shared: PanelController?

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let services: AppServices
    private var eventMonitor: Any?

    var isOpen: Bool { popover.isShown }
    var statusItemFrame: NSRect? { statusItem.button?.window?.frame }

    init(services: AppServices) {
        self.services = services
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "edithGlasses"
        statusItem.isVisible = true
        super.init()

        if let button = statusItem.button {
            button.image = Logo.menuBar
            button.action = #selector(statusClicked)
            button.target = self
        }

        popover.behavior = .transient
        popover.animates = true
    }

    @objc private func statusClicked() {
        toggle()
    }

    func toggle() {
        if popover.isShown { close() } else { open() }
    }

    func open() {
        guard !popover.isShown, let button = statusItem.button else { return }
        let host = NSHostingController(
            rootView: AnyView(RootView().environmentObject(services)))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        startEventMonitor()
    }

    func close() {
        guard popover.isShown else { return }
        popover.performClose(nil)
        popover.contentViewController = nil
        stopEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

enum AppState {
    @MainActor static let services = migratedServices()
}
