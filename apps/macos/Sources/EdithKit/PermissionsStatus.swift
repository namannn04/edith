import Foundation

public enum PermissionsStatus {
    public static var current: Bool {
        let d = SharedDefaults.store
        func on(_ key: String) -> Bool { d.object(forKey: key) as? Bool ?? false }
        return needsAttention(
            usageTab: on("tabUsageEnabled"), calendarTab: on("tabCalendarEnabled"),
            systemTab: on("tabSystemEnabled"),
            notifyMaster: d.bool(forKey: "notifyMaster"),
            calendar: d.bool(forKey: "permCalendarGranted"),
            accessibility: d.bool(forKey: "permAccessibilityGranted"),
            inputMonitoring: d.bool(forKey: "permInputMonitoringGranted"),
            notifications: d.bool(forKey: "permNotificationsGranted"))
    }

    public static func needsAttention(
        usageTab: Bool, calendarTab: Bool, systemTab _: Bool, notifyMaster: Bool,
        calendar: Bool, accessibility _: Bool, inputMonitoring _: Bool, notifications: Bool
    ) -> Bool {
        if calendarTab, !calendar { return true }
        if usageTab, notifyMaster, !notifications { return true }
        return false
    }
}
