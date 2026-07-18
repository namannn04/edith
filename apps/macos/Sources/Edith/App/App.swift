import EdithKit
import ServiceManagement
import SwiftUI

private let helperBundleIdentifier = "com.pulkit.edith.statusbar"

@MainActor
final class MainAppDelegate: NSObject, NSApplicationDelegate {
    private var quitObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var settingsChangeDebounce: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ExtensionDefaultsMigration.migrate()
        applyAppearance(SharedDefaults.store.string(forKey: "appearance") ?? "system")
        let showDockIcon = SharedDefaults.store.object(forKey: "showDockIcon") as? Bool ?? true
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        launchHelperIfNeeded()
        Task { await DashboardModel.shared.load() }
        nudgePermissionsOnFirstLaunch()
        MainWindow.open()
        quitObserver = IPC.observe(IPC.Name.quitMainApp) {
            NSApp.terminate(nil)
        }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: SharedDefaults.store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSettingsChangedBroadcast() }
        }
    }

    private func scheduleSettingsChangedBroadcast() {
        settingsChangeDebounce?.invalidate()
        settingsChangeDebounce = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            IPC.post(IPC.Name.settingsChanged)
        }
    }

    private func nudgePermissionsOnFirstLaunch() {
        let store = SharedDefaults.store
        guard store.object(forKey: "hasPromptedPermissions") == nil else { return }
        store.set(true, forKey: "hasPromptedPermissions")
        if PermissionsStatus.current {
            store.set(MainDestination.permissions.rawValue, forKey: "mainWindowSection")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { MainWindow.open() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private let retiredHelperBundleIdentifiers = [
    "com.pulkit.edith.panel", "com.pulkit.edith.bar", "com.pulkit.edith.menubar",
]

private func launchHelperIfNeeded() {
    for identifier in retiredHelperBundleIdentifiers {
        let retired = SMAppService.loginItem(identifier: identifier)
        if retired.status == .enabled {
            try? retired.unregister()
        }
    }
    let service = SMAppService.loginItem(identifier: helperBundleIdentifier)
    if service.status != .enabled {
        try? service.register()
    }
    let helperURL = Bundle.main.bundleURL
        .appendingPathComponent("Contents/Library/LoginItems/Edith.app")
    if let running = NSRunningApplication.runningApplications(
        withBundleIdentifier: helperBundleIdentifier
    ).first {
        guard let installedAt = helperInstalledDate(helperURL),
            let launchedAt = running.launchDate, launchedAt < installedAt
        else { return }
        running.forceTerminate()
        relaunchHelper(at: helperURL, after: running)
        return
    }
    NSWorkspace.shared.openApplication(
        at: helperURL, configuration: NSWorkspace.OpenConfiguration())
}

private func helperInstalledDate(_ helperURL: URL) -> Date? {
    let exec = helperURL.appendingPathComponent("Contents/MacOS/Edith")
    return (try? FileManager.default.attributesOfItem(atPath: exec.path)[.modificationDate])
        as? Date
}

private func relaunchHelper(at url: URL, after proc: NSRunningApplication) {
    DispatchQueue.global(qos: .userInitiated).async {
        for _ in 0..<50 where !proc.isTerminated {
            Thread.sleep(forTimeInterval: 0.1)
        }
        DispatchQueue.main.async {
            NSWorkspace.shared.openApplication(
                at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

@main
struct EdithApp: App {
    @NSApplicationDelegateAdaptor(MainAppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            SettingsRedirect()
        }
    }
}

private struct SettingsRedirect: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                SharedDefaults.store.set(
                    MainDestination.settings.rawValue, forKey: "mainWindowSection")
                DispatchQueue.main.async {
                    for window in NSApp.windows
                    where window.identifier?.rawValue.contains("Settings") == true
                        || window.title == "Edith Settings"
                    {
                        window.close()
                    }
                    MainWindow.open()
                }
            }
    }
}
