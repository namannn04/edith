import Foundation

public struct OnboardingPermission: Equatable, Sendable {
    public let permission: ExtensionPermission
    public let required: Bool

    public init(permission: ExtensionPermission, required: Bool) {
        self.permission = permission
        self.required = required
    }
}

public enum OnboardingFlow {
    public static let completionKey = "onboardingCompleted"

    public static func shouldShowOnboarding(defaults: UserDefaults = SharedDefaults.store) -> Bool {
        !defaults.bool(forKey: completionKey)
            && defaults.bool(forKey: ExtensionDefaultsMigration.freshInstallKey)
    }

    public static func grantedPermissions(
        defaults: UserDefaults = SharedDefaults.store
    ) -> [ExtensionPermission: Bool] {
        Dictionary(
            uniqueKeysWithValues: ExtensionPermission.allCases.map { permission in
                let granted: Bool
                if let key = permission.grantedDefaultsKey {
                    granted = defaults.bool(forKey: key)
                } else {
                    granted = false
                }
                return (permission, granted)
            })
    }

    public static func missingPermissions(
        selectedIDs: Set<String>,
        entries: [ExtensionRegistryEntry] = ExtensionRegistry.entries,
        granted: [ExtensionPermission: Bool]
    ) -> [OnboardingPermission] {
        let selectedEntries = entries.filter { selectedIDs.contains($0.id) }
        let required = Set(selectedEntries.flatMap(\.requiredPermissions))
        let optional = Set(selectedEntries.flatMap(\.optionalPermissions)).subtracting(required)
        let missingRequired = ExtensionPermission.allCases.filter {
            required.contains($0) && granted[$0] != true
        }
        let missingOptional = ExtensionPermission.allCases.filter {
            optional.contains($0) && granted[$0] != true
        }
        return missingRequired.map { OnboardingPermission(permission: $0, required: true) }
            + missingOptional.map { OnboardingPermission(permission: $0, required: false) }
    }

    public static func grantedPermissionCount(
        selectedIDs: Set<String>,
        entries: [ExtensionRegistryEntry] = ExtensionRegistry.entries,
        granted: [ExtensionPermission: Bool]
    ) -> Int {
        let permissions = Set(
            entries.filter { selectedIDs.contains($0.id) }.flatMap {
                $0.requiredPermissions + $0.optionalPermissions
            })
        return permissions.filter { granted[$0] == true }.count
    }

    public static func seenKey(for entry: ExtensionRegistryEntry) -> String {
        "extensionPermissionsSeen.\(entry.id)"
    }

    public static func finish(
        selectedIDs: Set<String>,
        entries: [ExtensionRegistryEntry] = ExtensionRegistry.entries,
        defaults: UserDefaults = SharedDefaults.store
    ) {
        for entry in entries where selectedIDs.contains(entry.id) {
            defaults.set(true, forKey: entry.defaultsKey)
            defaults.set(true, forKey: seenKey(for: entry))
        }
        defaults.set(true, forKey: completionKey)
    }

    public static func skip(defaults: UserDefaults = SharedDefaults.store) {
        defaults.set(true, forKey: completionKey)
    }
}
