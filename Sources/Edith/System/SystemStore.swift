import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import IOKit.pwr_mgt
import SwiftUI

/// System tab: Prevent Sleep (IOKit power assertion, the Amphetamine
/// mechanism) and Keyboard Cleaning (CGEventTap swallowing every key incl.
/// the function/media row, with an overlay + failsafe so nothing can stick).
@MainActor
final class SystemStore: ObservableObject {
    // MARK: Prevent sleep

    @Published private(set) var preventingSleep = false
    private var assertionID: IOPMAssertionID = 0

    // MARK: Keyboard cleaning

    enum CleaningPhase { case idle, arming, cleaning }
    @Published private(set) var phase = CleaningPhase.idle
    @Published private(set) var armingCountdown = 0
    @Published private(set) var failsafeRemaining = 0
    @Published private(set) var hasInputMonitoring = false
    @Published private(set) var hasAccessibility = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var armTimer: Timer?
    private var failsafeTimer: Timer?
    private var healthTimer: Timer?
    private var overlays: [NSWindow] = []
    private var terminateObserver: NSObjectProtocol?

    private let armingSeconds = 3
    private let failsafeSeconds = 60

    init() {
        refreshPermissions()
        if UserDefaults.standard.bool(forKey: "preventSleep") {
            enableSleepPrevention()
        }
        // Explicit teardown on quit - never trust deinit for a power
        // assertion or a live event tap.
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.shutdown() }
        }
    }

    /// Tab disabled or app quitting: release everything OS-visible.
    func shutdown() {
        stopCleaning()
        if preventingSleep {
            IOPMAssertionRelease(assertionID)
            preventingSleep = false
        }
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
            self.terminateObserver = nil
        }
    }

    // MARK: - Prevent sleep

    func setPreventSleep(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "preventSleep")
        on ? enableSleepPrevention() : disableSleepPrevention()
    }

    private func enableSleepPrevention() {
        guard !preventingSleep else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Edith: Prevent Sleep is on" as CFString,
            &assertionID)
        preventingSleep = (result == kIOReturnSuccess)
    }

    private func disableSleepPrevention() {
        guard preventingSleep else { return }
        IOPMAssertionRelease(assertionID)
        preventingSleep = false
    }

    // MARK: - Permissions

    func refreshPermissions() {
        hasInputMonitoring = CGPreflightListenEventAccess()
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        hasAccessibility = AXIsProcessTrustedWithOptions([key: false] as CFDictionary)
        // The preflight flags lag behind a fresh grant until the app
        // relaunches. The tap itself is the ground truth: if we can create
        // one right now, both permissions effectively work right now.
        if (!hasInputMonitoring || !hasAccessibility), phase == .idle, probeTap() {
            hasInputMonitoring = true
            hasAccessibility = true
        }
    }

    /// Try to create (and immediately destroy) a real event tap.
    private func probeTap() -> Bool {
        let callback: CGEventTapCallBack = { _, _, event, _ in
            Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1) << CGEventType.keyDown.rawValue,
            callback: callback,
            userInfo: nil)
        else { return false }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        return true
    }

    /// Fresh process picks up fresh permission state.
    func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }

    // The system prompt for each permission appears only ONCE per app
    // identity - later requests silently no-op. So Grant always also opens
    // the right System Settings pane, where the toggle actually lives.
    func requestInputMonitoring() {
        CGRequestListenEventAccess()
        openInputMonitoringSettings()
        recheckSoon()
    }

    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        openAccessibilitySettings()
        recheckSoon()
    }

    func openInputMonitoringSettings() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func recheckSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshPermissions()
        }
    }

    // MARK: - Keyboard cleaning

    func beginCleaning() {
        refreshPermissions()
        guard phase == .idle, hasInputMonitoring, hasAccessibility else { return }
        dismissPanel() // the overlay takes over from here
        phase = .arming
        armingCountdown = armingSeconds
        showOverlays()
        armTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                self.armingCountdown -= 1
                if self.armingCountdown <= 0 {
                    timer.invalidate()
                    self.startCleaning()
                }
            }
        }
    }

    private func startCleaning() {
        guard installEventTap() else {
            stopCleaning()
            return
        }
        phase = .cleaning
        failsafeRemaining = failsafeSeconds
        failsafeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                self.failsafeRemaining -= 1
                if self.failsafeRemaining <= 0 {
                    timer.invalidate()
                    self.stopCleaning()
                }
            }
        }
        // macOS can silently disable a tap (timeout, re-sign); re-arm it.
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let tap = self.eventTap else { return }
                if !CGEvent.tapIsEnabled(tap: tap) {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
        }
    }

    func stopCleaning() {
        uninstallEventTap()
        armTimer?.invalidate()
        failsafeTimer?.invalidate()
        healthTimer?.invalidate()
        armTimer = nil
        failsafeTimer = nil
        healthTimer = nil
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
        phase = .idle
    }

    private func showOverlays() {
        guard overlays.isEmpty else { return }
        for screen in NSScreen.screens { // every display, not just .main
            let window = CleaningOverlayWindow(
                screen: screen,
                rootView: CleaningOverlayView(store: self))
            window.orderFrontRegardless()
            overlays.append(window)
        }
    }

    // MARK: Event tap

    private func installEventTap() -> Bool {
        func bit(_ type: CGEventType) -> CGEventMask { CGEventMask(1) << type.rawValue }
        // systemDefined carries the function-row/media keys - without it,
        // letters block but volume/brightness/play-pause leak through.
        let mask: CGEventMask =
            bit(.keyDown) | bit(.keyUp) | bit(.flagsChanged)
            | (CGEventMask(1) << 14) // NX_SYSDEFINED (media/function keys)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let store = Unmanaged<SystemStore>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = store.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return nil
            }
            return nil // swallow every keyboard event while cleaning
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func uninstallEventTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
    }
}
