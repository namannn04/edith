import Foundation
import Testing

@testable import EdithKit

@Suite struct LidAwakeTests {
    @Test func commandTogglesTheLidCloseSleepPathway() {
        #expect(LidAwakeCommand.arguments(active: true) == ["-a", "disablesleep", "1"])
        #expect(LidAwakeCommand.arguments(active: false) == ["-a", "disablesleep", "0"])
        #expect(LidAwakeCommand.shellCommand(active: true) == "/usr/bin/pmset -a disablesleep 1")
    }

    @Test func privilegedScriptAsksForAdministratorRights() {
        let script = LidAwakeCommand.privilegedScript(active: true)
        #expect(script.hasPrefix("do shell script \""))
        #expect(script.hasSuffix("\" with administrator privileges"))
        #expect(script.contains(LidAwakeCommand.shellCommand(active: true)))
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

    @Test func successfulRunIsApplied() {
        #expect(LidAwakeCommand.outcome(status: 0, errorOutput: "") == .applied)
    }

    @Test func dismissedPasswordPromptIsNotAnError() {
        let cancelled = "execution error: User canceled. (-128)"
        #expect(LidAwakeCommand.outcome(status: 1, errorOutput: cancelled) == .cancelled)
    }

    @Test func failureKeepsTheReasonUserFacing() {
        let denied = "execution error: The administrator password was incorrect. (-60007)"
        #expect(LidAwakeCommand.outcome(status: 1, errorOutput: denied) == .failed(denied))
        #expect(
            LidAwakeCommand.outcome(status: 3, errorOutput: "   \n")
                == .failed("pmset exited with status 3"))
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
}
