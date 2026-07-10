import Foundation

public enum FeatureGates {
    public static func presenterActive(enabled: Bool, manual: Bool, autoActive: Bool) -> Bool {
        enabled && (manual || autoActive)
    }

    public static func presenterDetectorWanted(presenterEnabled: Bool, autoEnabled: Bool) -> Bool {
        presenterEnabled && autoEnabled
    }

    public static func preventSleepPersisted(systemOn: Bool, current: Bool) -> Bool {
        systemOn && current
    }
}
