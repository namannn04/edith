import EdithKit
import ServiceManagement
import SwiftUI

private let helperBundleIdentifier = "com.pulkit.edith.statusbar"

@MainActor
final class MainAppDelegate: NSObject, NSApplicationDelegate {
    private var quitObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var settingsChangeDebounce: Timer?
    private let licenseState = LicenseState()
    private let licenseClient = LicenseClient()
    private var licensedAppStarted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyAppearance(SharedDefaults.store.string(forKey: "appearance") ?? "system")
        if (try? licenseState.gateDecision()) == .proceed {
            startLicensedApp()
            verifyLicenseInBackground()
        } else {
            presentActivationGate()
        }
    }

    private func startLicensedApp() {
        guard !licensedAppStarted else {
            showInitialWindow()
            return
        }
        licensedAppStarted = true
        ExtensionDefaultsMigration.migrate()
        Repo.prepareStoredPaths()
        applyConfiguredActivationPolicy()
        launchHelperIfNeeded()
        let dashboard = DashboardModel.shared
        dashboard.syncExtensionState()
        if SharedDefaults.store.bool(forKey: "tabUsageEnabled") {
            Task { await dashboard.load() }
        }
        showInitialWindow()
        quitObserver = IPC.observe(IPC.Name.quitMainApp) {
            NSApp.terminate(nil)
        }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: SharedDefaults.store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                DashboardModel.shared.syncExtensionState()
                self?.scheduleSettingsChangedBroadcast()
            }
        }
    }

    private func applyConfiguredActivationPolicy() {
        let showDockIcon = SharedDefaults.store.object(forKey: "showDockIcon") as? Bool ?? true
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    private func showInitialWindow() {
        if OnboardingFlow.shouldShowOnboarding() {
            OnboardingWindow.open()
        } else {
            MainWindow.open()
        }
    }

    private func presentActivationGate() {
        NSApp.setActivationPolicy(.regular)
        for window in NSApp.windows where window.identifier != ActivationWindow.identifier {
            window.orderOut(nil)
        }
        ActivationWindow.open(licenseState: licenseState, client: licenseClient) { [weak self] in
            self?.startLicensedApp()
        }
    }

    private func verifyLicenseInBackground() {
        guard let key = try? licenseState.licenseKey(), let machine = hardwareUUID() else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let valid = try await licenseClient.verify(key: key, hardwareUuid: machine)
                guard !valid else { return }
                licenseState.markVerificationFailed()
                presentActivationGate()
            } catch {
                return
            }
        }
    }

    private func scheduleSettingsChangedBroadcast() {
        settingsChangeDebounce?.invalidate()
        settingsChangeDebounce = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            IPC.post(IPC.Name.settingsChanged)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard (try? licenseState.gateDecision()) == .proceed else {
            presentActivationGate()
            return true
        }
        if !licensedAppStarted {
            startLicensedApp()
        } else if !hasVisibleWindows {
            showInitialWindow()
        }
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
                    if (try? LicenseState().gateDecision()) == .proceed {
                        MainWindow.open()
                    }
                }
            }
    }
}
