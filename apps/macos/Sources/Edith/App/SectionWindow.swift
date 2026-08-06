import AppKit
import EdithKit
import SwiftUI

struct DetachedSectionView: View {
    let destination: MainDestination
    @AppStorage("theme", store: SharedDefaults.store) private var themeName = "accent"
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            detail
                .tint(themeColor(themeName))
                .environment(\.compactLayout, geo.size.width < UIScale.pt(640))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    destination.usesPaperBackground
                        ? DashSkin.paper(scheme == .dark)
                        : Color(nsColor: .windowBackgroundColor))
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch destination {
        case .home: HomePage()
        case .dashboard: DashboardView()
        case .music: MusicPage()
        case .calendar: CalendarPage()
        case .system: SystemPage()
        case .machines: MachinesPage()
        case .extensions: ExtensionsPane()
        case .settings: SettingsPane(updater: UpdaterModel())
        case .about: AboutPane()
        }
    }
}

@MainActor
enum SectionWindow {
    private static var windows: [String: NSWindow] = [:]

    static func open(_ destination: MainDestination, title: String? = nil) {
        let key = destination.rawValue
        if let existing = windows[key] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = title ?? destination.title
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 560, height: 420)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "EdithSection"
        let hosting = NSHostingController(
            rootView: ZoomableRoot { DetachedSectionView(destination: destination) })
        hosting.sizingOptions = []
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 860, height: 640))
        window.setFrameAutosaveName("EdithSection.\(key)")
        if window.frame.origin == .zero { window.center() }
        cascade(window)
        window.delegate = SectionWindowDelegate.shared
        windows[key] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func isOpen(_ destination: MainDestination) -> Bool {
        windows[destination.rawValue] != nil
    }

    static func forget(_ window: NSWindow) {
        guard let key = windows.first(where: { $0.value === window })?.key else { return }
        windows.removeValue(forKey: key)
    }

    static func closeAll() {
        for window in windows.values { window.close() }
        windows = [:]
    }

    private static func cascade(_ window: NSWindow) {
        guard windows.count > 0, let reference = NSApp.keyWindow ?? windows.values.first else {
            return
        }
        let offset = CGFloat(22 * (windows.count + 1))
        let origin = NSPoint(
            x: reference.frame.origin.x + offset, y: reference.frame.origin.y - offset)
        if let screen = window.screen ?? NSScreen.main, screen.visibleFrame.contains(origin) {
            window.setFrameOrigin(origin)
        }
    }
}

@MainActor
final class SectionWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = SectionWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        SectionWindow.forget(window)
    }
}

enum SectionWindowCommand {
    static func shouldDetach(_ modifiers: EventModifiers) -> Bool {
        modifiers.contains(.command)
    }

    static func detachableDestinations(visibleHomeItems: [MainDestination]) -> [MainDestination] {
        visibleHomeItems + [.extensions, .settings]
    }
}
