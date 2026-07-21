import AVFoundation
import AppKit
import ApplicationServices
import CoreGraphics
import EdithKit
import EventKit
import SwiftUI
import UserNotifications

@MainActor
final class PermissionsModel: ObservableObject {
    static let shared = PermissionsModel()

    @Published private(set) var calendar = false
    @Published private(set) var notifications = false
    @Published private(set) var accessibility = false
    @Published private(set) var inputMonitoring = false
    @Published private(set) var fullDisk = false
    @Published private(set) var screenRecording = false
    @Published private(set) var camera = false

    private let eventStore = EKEventStore()
    private var ipcTokens: [NSObjectProtocol] = []

    func startIPCBridge() {
        guard ipcTokens.isEmpty else { return }
        ipcTokens = [
            IPC.observe(IPC.Name.requestPermissionsRefresh) { [weak self] in self?.refresh() },
            IPC.observe(IPC.Name.grantCalendar) { [weak self] in self?.grantCalendar() },
            IPC.observe(IPC.Name.grantNotifications) { [weak self] in
                self?.grantNotifications()
            },
            IPC.observe(IPC.Name.grantAccessibility) { [weak self] in
                self?.grantAccessibility()
            },
            IPC.observe(IPC.Name.grantInputMonitoring) { [weak self] in
                self?.grantInputMonitoring()
            },
            IPC.observe(IPC.Name.grantFullDisk) { [weak self] in self?.grantFullDisk() },
            IPC.observe(IPC.Name.grantScreenRecording) { [weak self] in
                self?.grantScreenRecording()
            },
            IPC.observe(IPC.Name.grantCamera) { [weak self] in self?.grantCamera() },
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
        ]
    }

    func refresh() {
        calendar = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        accessibility = AXIsProcessTrusted()
        inputMonitoring = CGPreflightListenEventAccess()
        fullDisk = Self.hasFullDiskAccess()
        screenRecording = CGPreflightScreenCaptureAccess()
        camera = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        mirrorToSharedDefaults()
        Task { @MainActor in
            let status = await UNUserNotificationCenter.current()
                .notificationSettings().authorizationStatus
            notifications = status == .authorized || status == .provisional
            mirrorToSharedDefaults()
        }
    }

    private func mirrorToSharedDefaults() {
        let d = SharedDefaults.store
        func setIfChanged(_ value: Bool, _ key: String) {
            if d.object(forKey: key) as? Bool != value { d.set(value, forKey: key) }
        }
        setIfChanged(calendar, "permCalendarGranted")
        setIfChanged(notifications, "permNotificationsGranted")
        setIfChanged(accessibility, "permAccessibilityGranted")
        setIfChanged(inputMonitoring, "permInputMonitoringGranted")
        setIfChanged(fullDisk, "permFullDiskGranted")
        setIfChanged(screenRecording, "permScreenRecordingGranted")
        setIfChanged(camera, "permCameraGranted")
        IPC.post(IPC.Name.permissionsRefreshed)
    }

    var needsAttention: Bool { PermissionsStatus.current }

    func grantCalendar() {
        Task { @MainActor in
            _ = try? await eventStore.requestFullAccessToEvents()
            refresh()
        }
        openSecuritySettings("Privacy_Calendars")
    }

    func grantNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
            _, _ in
            Task { @MainActor in self.refresh() }
        }
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
    }

    func grantAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        openSecuritySettings("Privacy_Accessibility")
        refreshAfterGrant()
    }

    func grantInputMonitoring() {
        CGRequestListenEventAccess()
        openSecuritySettings("Privacy_ListenEvent")
        refreshAfterGrant()
    }

    func grantFullDisk() {
        openSecuritySettings("Privacy_AllFiles")
        refreshAfterGrant()
    }

    func grantScreenRecording() {
        CGRequestScreenCaptureAccess()
        openSecuritySettings("Privacy_ScreenCapture")
        refreshAfterGrant()
    }

    func grantCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { _ in
                Task { @MainActor in self.refresh() }
            }
        default:
            openSecuritySettings("Privacy_Camera")
            refreshAfterGrant()
        }
    }

    private func openSecuritySettings(_ anchor: String) {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
    }

    private func refreshAfterGrant() {
        refresh()
        for delay in [0.5, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refresh()
            }
        }
    }

    static func hasFullDiskAccess() -> Bool {
        let tcc = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        guard let handle = try? FileHandle(forReadingFrom: tcc) else { return false }
        try? handle.close()
        return true
    }
}
