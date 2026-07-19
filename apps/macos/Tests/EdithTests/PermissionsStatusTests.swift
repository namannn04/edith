import Testing
@testable import EdithKit

@Suite struct PermissionsStatusTests {
    func needsAttention(
        usageTab: Bool = false, calendarTab: Bool = false, systemTab: Bool = false,
        notifyMaster: Bool = false,
        calendar: Bool = true, accessibility: Bool = true, inputMonitoring: Bool = true,
        notifications: Bool = true
    ) -> Bool {
        PermissionsStatus.needsAttention(
            usageTab: usageTab, calendarTab: calendarTab, systemTab: systemTab,
            notifyMaster: notifyMaster,
            calendar: calendar, accessibility: accessibility, inputMonitoring: inputMonitoring,
            notifications: notifications)
    }

    @Test func allGrantedNeedsNothing() {
        #expect(
            !needsAttention(
                usageTab: true, calendarTab: true, systemTab: true, notifyMaster: true))
    }

    @Test func missingPermissionOnlyWarnsWhenFeatureIsOn() {
        #expect(!needsAttention(calendarTab: false, calendar: false))
        #expect(needsAttention(calendarTab: true, calendar: false))
    }

    @Test func systemTabDoesNotRequireKeyboardCleaningPermissions() {
        #expect(!needsAttention(systemTab: true, accessibility: false))
        #expect(!needsAttention(systemTab: true, inputMonitoring: false))
    }

    @Test func notificationsWarnOnlyWhenMasterIsOn() {
        #expect(!needsAttention(notifyMaster: false, notifications: false))
        #expect(needsAttention(usageTab: true, notifyMaster: true, notifications: false))
        #expect(!needsAttention(usageTab: false, notifyMaster: true, notifications: false))
    }
}
