import Foundation

public enum ExtensionDefaultsMigration {
    public static let markerKey = "extensionDefaultsMigrated"

    public static func migrate(
        defaults: UserDefaults = SharedDefaults.store,
        markerKey: String = ExtensionDefaultsMigration.markerKey
    ) {
        guard defaults.object(forKey: markerKey) == nil else { return }
        let hasPriorInstall =
            defaults.object(forKey: "hasPromptedPermissions") != nil
            || ExtensionRegistry.entries.contains {
                defaults.object(forKey: $0.defaultsKey) != nil
            }
        if hasPriorInstall {
            for entry in ExtensionRegistry.entries {
                let value =
                    defaults.object(forKey: entry.defaultsKey) as? Bool
                    ?? legacyDefaults[entry.defaultsKey, default: false]
                defaults.set(value, forKey: entry.defaultsKey)
            }
        }
        defaults.set(true, forKey: markerKey)
    }

    private static let legacyDefaults: [String: Bool] = [
        "tabUsageEnabled": true,
        "tabSystemEnabled": true,
        "menuBarSystemStats": false,
        "micMuteEnabled": false,
        "tabMusicEnabled": true,
        "tabCalendarEnabled": true,
        "notchShelfEnabled": false,
        "clipboardEnabled": false,
        "focusDimEnabled": false,
        "presenterEnabled": true,
        "colorPickerEnabled": false,
    ]
}
