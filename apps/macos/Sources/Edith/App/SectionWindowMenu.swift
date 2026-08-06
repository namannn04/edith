import AppKit
import EdithKit

enum WindowTabKeyCommand: Equatable {
    case selectTab(index: Int)
    case nextTab
    case previousTab

    static func resolve(
        characters: String?, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, tabbed: Bool
    ) -> WindowTabKeyCommand? {
        guard tabbed else { return nil }
        let flags = modifiers.intersection(.deviceIndependentFlagsMask)
        if keyCode == 48, flags.contains(.control), !flags.contains(.command) {
            return flags.contains(.shift) ? .previousTab : .nextTab
        }
        guard flags == .command, let characters, let value = Int(characters), value >= 1,
            value <= 9
        else { return nil }
        return .selectTab(index: value - 1)
    }
}

@MainActor
enum SectionWindowMenu {
    private static var installed = false
    private static var hintMonitor: Any?
    private static var keyMonitor: Any?

    static func install() {
        guard !installed else { return }
        installed = true
        installMenuItems()
        installMonitors()
    }

    private static func installMenuItems() {
        guard let mainMenu = NSApp.mainMenu,
            let submenu =
                (mainMenu.items.first { $0.submenu?.title == "Window" }
                ?? mainMenu.items.first { $0.title == "Window" })?.submenu
        else { return }
        let target = SectionWindowMenuTarget.shared
        var index = 0
        let next = NSMenuItem(
            title: "Show Next Tab", action: #selector(SectionWindowMenuTarget.nextTab(_:)),
            keyEquivalent: "\t")
        next.keyEquivalentModifierMask = .control
        next.target = target
        submenu.insertItem(next, at: index)
        index += 1
        let previous = NSMenuItem(
            title: "Show Previous Tab",
            action: #selector(SectionWindowMenuTarget.previousTab(_:)), keyEquivalent: "\t")
        previous.keyEquivalentModifierMask = [.control, .shift]
        previous.target = target
        submenu.insertItem(previous, at: index)
        index += 1
        submenu.insertItem(NSMenuItem.separator(), at: index)
        index += 1
        for destination in MainDestination.homeItems + [.extensions, .settings] {
            guard destination != .about else { continue }
            let item = NSMenuItem(
                title: "Open \(destination.title) in New Window",
                action: #selector(SectionWindowMenuTarget.openSection(_:)), keyEquivalent: "")
            item.target = target
            item.representedObject = destination.rawValue
            submenu.insertItem(item, at: index)
            index += 1
        }
        submenu.insertItem(NSMenuItem.separator(), at: index)
    }

    private static func installMonitors() {
        hintMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let commandDown = event.modifierFlags.contains(.command)
            MainActor.assumeIsolated { WindowTabs.showHints(commandDown) }
            return event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let characters = event.charactersIgnoringModifiers
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags
            let handled = MainActor.assumeIsolated { () -> Bool in
                let window = NSApp.keyWindow
                guard
                    let command = WindowTabKeyCommand.resolve(
                        characters: characters, keyCode: keyCode, modifiers: modifiers,
                        tabbed: WindowTabs.isTabbed(window))
                else { return false }
                switch command {
                case let .selectTab(index):
                    return WindowTabs.selectTab(index: index, in: window)
                case .nextTab:
                    return WindowTabs.selectNextTab(in: window, backwards: false)
                case .previousTab:
                    return WindowTabs.selectNextTab(in: window, backwards: true)
                }
            }
            return handled ? nil : event
        }
    }
}

@MainActor
final class SectionWindowMenuTarget: NSObject {
    static let shared = SectionWindowMenuTarget()

    @objc func openSection(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
            let destination = MainDestination(rawValue: raw)
        else { return }
        SectionWindow.open(destination, mode: .alwaysNew)
    }

    @objc func nextTab(_ sender: NSMenuItem) {
        _ = WindowTabs.selectNextTab(in: NSApp.keyWindow, backwards: false)
    }

    @objc func previousTab(_ sender: NSMenuItem) {
        _ = WindowTabs.selectNextTab(in: NSApp.keyWindow, backwards: true)
    }
}
