import AppKit
import EdithKit

@MainActor
enum SectionWindowMenu {
    private static var installed = false

    static func install() {
        guard !installed, let mainMenu = NSApp.mainMenu else { return }
        installed = true
        let windowMenuItem =
            mainMenu.items.first { $0.submenu?.title == "Window" }
            ?? mainMenu.items.first { $0.title == "Window" }
        guard let submenu = windowMenuItem?.submenu else { return }
        let target = SectionWindowMenuTarget.shared
        submenu.insertItem(NSMenuItem.separator(), at: 0)
        var index = 0
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
    }
}

@MainActor
final class SectionWindowMenuTarget: NSObject {
    static let shared = SectionWindowMenuTarget()

    @objc func openSection(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
            let destination = MainDestination(rawValue: raw)
        else { return }
        SectionWindow.open(destination)
    }
}
