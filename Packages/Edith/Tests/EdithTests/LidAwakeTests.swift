import Foundation
import Testing

@testable import EdithKit
@testable import EdithHelper

@Suite struct LidAwakeTests {
    @Test func commandTogglesTheLidCloseSleepPathway() {
        #expect(LidAwakeCommand.arguments(active: true) == ["-a", "disablesleep", "1"])
        #expect(LidAwakeCommand.arguments(active: false) == ["-a", "disablesleep", "0"])
        #expect(LidAwakeCommand.shellCommand(active: true) == "/usr/bin/pmset -a disablesleep 1")
    }

    @Test func unavailableHelperErrorsGiveTheCorrectRecovery() {
        let approval = LidAwakePrivilegedClientError.helperUnavailable(.awaitingApproval)
        #expect(
            approval.errorDescription?.contains("System Settings > General > Login Items") == true)
        let missing = LidAwakePrivilegedClientError.helperUnavailable(.notFound)
        #expect(missing.errorDescription?.contains("Reinstall Edith") == true)
        let registration = LidAwakePrivilegedClientError.helperUnavailable(.notRegistered)
        #expect(registration.errorDescription?.contains("Reopen Edith") == true)
    }

    @Test func daemonIsPackagedInsideItsCallingApp() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistURL = root.appendingPathComponent("Resources/com.pulkit.edith.lidawake.plist")
        let plistData = try Data(contentsOf: plistURL)
        let plist = try #require(
            PropertyListSerialization.propertyList(from: plistData, format: nil)
                as? [String: Any])
        #expect(
            plist["BundleProgram"] as? String
                == "Contents/Library/PrivilegedHelperTools/com.pulkit.edith.lidawake")
        let associated = plist["AssociatedBundleIdentifiers"] as? [String]
        #expect(associated?.contains("com.pulkit.edith.statusbar") == true)
        let build = try String(
            contentsOf: root.appendingPathComponent("build.sh"), encoding: .utf8)
        #expect(
            build.contains(
                "PRIVILEGED_HELPER=\"$HELPER/Contents/Library/PrivilegedHelperTools/com.pulkit.edith.lidawake\""
            ))
        #expect(
            build.contains(
                "LAUNCH_DAEMONS=\"$HELPER/Contents/Library/LaunchDaemons\""))
    }

    @Test func powerSettingsReportSleepDisabled() {
        let on = """
            System-wide power settings:
             SleepDisabled		1
            Currently in use:
             standby              1
            """
        let off = """
            System-wide power settings:
             SleepDisabled		0
            Currently in use:
             standby              1
            """
        #expect(LidAwakeCommand.sleepDisabled(inPowerSettings: on))
        #expect(!LidAwakeCommand.sleepDisabled(inPowerSettings: off))
        #expect(!LidAwakeCommand.sleepDisabled(inPowerSettings: "Currently in use:\n standby 1"))
        #expect(!LidAwakeCommand.sleepDisabled(inPowerSettings: ""))
    }

    @Test func installedAndActiveAreSeparateState() {
        #expect(LidAwakeState.enabledKey != LidAwakeState.activeKey)
        let defaults = UserDefaults(suiteName: "test.lidawake")!
        defaults.removePersistentDomain(forName: "test.lidawake")
        defer { defaults.removePersistentDomain(forName: "test.lidawake") }

        defaults.set(true, forKey: LidAwakeState.enabledKey)
        #expect(LidAwakeState.isEnabled(defaults))
        #expect(!LidAwakeState.isActive(defaults))

        LidAwakeState.setActive(true, defaults)
        #expect(LidAwakeState.isActive(defaults))

        LidAwakeState.setActive(false, defaults)
        #expect(!LidAwakeState.isActive(defaults))
        #expect(LidAwakeState.isEnabled(defaults), "closing the lid again must keep it installed")
    }

    @Test func inactiveWhenTheExtensionIsOff() {
        let defaults = UserDefaults(suiteName: "test.lidawake.off")!
        defaults.removePersistentDomain(forName: "test.lidawake.off")
        defer { defaults.removePersistentDomain(forName: "test.lidawake.off") }

        defaults.set(true, forKey: LidAwakeState.activeKey)
        #expect(!LidAwakeState.isActive(defaults))
    }

    @Test func sleepIsRestoredOnQuitUnlessTurnedOff() {
        let defaults = UserDefaults(suiteName: "test.lidawake.quit")!
        defaults.removePersistentDomain(forName: "test.lidawake.quit")
        defer { defaults.removePersistentDomain(forName: "test.lidawake.quit") }

        #expect(LidAwakeState.restoresOnQuit(defaults))
        defaults.set(false, forKey: LidAwakeState.restoreOnQuitKey)
        #expect(!LidAwakeState.restoresOnQuit(defaults))
    }

    @Test func batteryPolicySuspendsBelowThresholdAndResumesOnAC() {
        #expect(
            LidAwakeBatteryPolicy.decide(
                intent: true, suspended: false, percent: 9, onAC: false, threshold: 10)
                == .suspend)
        #expect(
            LidAwakeBatteryPolicy.decide(
                intent: true, suspended: true, percent: 14, onAC: true, threshold: 10)
                == .none)
        #expect(
            LidAwakeBatteryPolicy.decide(
                intent: true, suspended: true, percent: 15, onAC: true, threshold: 10)
                == .resume)
    }

    @Test func batteryOverrideLastsUntilAC() {
        #expect(LidAwakeBatteryPolicy.shouldKeepOverride(true, onAC: false))
        #expect(!LidAwakeBatteryPolicy.shouldKeepOverride(true, onAC: true))
        #expect(!LidAwakeBatteryPolicy.shouldKeepOverride(false, onAC: false))
    }

    @Test func lidSessionEndsAfterCloseAndReopen() {
        var tracker = LidAwakeLidSessionTracker()
        tracker.start(lidClosed: false)
        #expect(tracker.isActive)
        let remainedOpen = tracker.handle(lidClosed: false)
        #expect(!remainedOpen)
        let startedSession = tracker.handle(lidClosed: true)
        #expect(!startedSession)
        let endedSession = tracker.handle(lidClosed: false)
        #expect(endedSession)
        #expect(!tracker.isActive)
    }

    @Test func lidSessionStartedWithClosedLidWaitsForReopen() {
        var tracker = LidAwakeLidSessionTracker()
        tracker.start(lidClosed: true)
        let remainedClosed = tracker.handle(lidClosed: true)
        #expect(!remainedClosed)
        let endedSession = tracker.handle(lidClosed: false)
        #expect(endedSession)
    }
}
