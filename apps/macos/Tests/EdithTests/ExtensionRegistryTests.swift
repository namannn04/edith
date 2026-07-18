import Foundation
import Testing

@testable import EdithKit

@Suite struct ExtensionRegistryTests {
    private let knownDefaultsKeys: Set<String> = [
        "tabUsageEnabled",
        "tabSystemEnabled",
        "menuBarSystemStats",
        "micMuteEnabled",
        "tabMusicEnabled",
        "tabCalendarEnabled",
        "notchShelfEnabled",
        "clipboardEnabled",
        "focusDimEnabled",
        "presenterEnabled",
        "colorPickerEnabled",
    ]

    @Test func registryIdentifiersAreUnique() {
        let identifiers = ExtensionRegistry.entries.map(\.id)
        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test func registryDefaultsKeysAreUniqueAndComplete() {
        let defaultsKeys = ExtensionRegistry.entries.map(\.defaultsKey)
        #expect(Set(defaultsKeys).count == defaultsKeys.count)
        #expect(Set(defaultsKeys) == knownDefaultsKeys)
    }

    @Test func featuredEntriesArePresent() {
        let featuredIdentifiers = Set(
            ExtensionRegistry.entries.filter(\.featured).map(\.id))
        #expect(featuredIdentifiers == ["usage", "system", "notchShelf", "clipboard"])
    }

    @Test func missingRequiredPermissionsShowSheet() {
        let entry = ExtensionRegistry.entries.first { $0.id == "system" }!
        let decision = ExtensionPermissionFlow.decision(
            for: entry, granted: [.accessibility: true, .inputMonitoring: false],
            hasSeenPermissions: true)
        #expect(
            decision
                == .showSheet(
                    required: [.inputMonitoring], optional: []))
    }

    @Test func grantedRequiredPermissionsEnableDirectly() {
        let entry = ExtensionRegistry.entries.first { $0.id == "system" }!
        let decision = ExtensionPermissionFlow.decision(
            for: entry, granted: [.accessibility: true, .inputMonitoring: true],
            hasSeenPermissions: false)
        #expect(decision == .enableDirectly)
    }

    @Test func unseenMissingOptionalPermissionsShowSheet() {
        let entry = ExtensionRegistry.entries.first { $0.id == "notchShelf" }!
        let decision = ExtensionPermissionFlow.decision(
            for: entry, granted: [.bluetooth: false, .camera: true],
            hasSeenPermissions: false)
        #expect(
            decision
                == .showSheet(required: [], optional: [.bluetooth]))
    }

    @Test func seenOptionalPermissionsEnableDirectly() {
        let entry = ExtensionRegistry.entries.first { $0.id == "notchShelf" }!
        let decision = ExtensionPermissionFlow.decision(
            for: entry, granted: [.bluetooth: false, .camera: false],
            hasSeenPermissions: true)
        #expect(decision == .enableDirectly)
    }

    @Test func grantedOptionalPermissionsEnableDirectlyWithoutPriorEnable() {
        let entry = ExtensionRegistry.entries.first { $0.id == "clipboard" }!
        let decision = ExtensionPermissionFlow.decision(
            for: entry, granted: [.accessibility: true], hasSeenPermissions: false)
        #expect(decision == .enableDirectly)
    }

    @Test func freshInstallLeavesExtensionsOff() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ExtensionDefaultsMigration.migrate(defaults: defaults)

        #expect(defaults.bool(forKey: ExtensionDefaultsMigration.markerKey))
        for key in knownDefaultsKeys {
            #expect(defaults.object(forKey: key) == nil)
            #expect(!defaults.bool(forKey: key))
        }
    }

    @Test func priorInstallPreservesEffectiveLegacyValues() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "hasPromptedPermissions")
        defaults.set(false, forKey: "tabUsageEnabled")
        defaults.set(true, forKey: "clipboardEnabled")

        ExtensionDefaultsMigration.migrate(defaults: defaults)

        let expected: [String: Bool] = [
            "tabUsageEnabled": false,
            "tabSystemEnabled": true,
            "menuBarSystemStats": false,
            "micMuteEnabled": false,
            "tabMusicEnabled": true,
            "tabCalendarEnabled": true,
            "notchShelfEnabled": false,
            "clipboardEnabled": true,
            "focusDimEnabled": false,
            "presenterEnabled": true,
            "colorPickerEnabled": false,
        ]
        for (key, value) in expected {
            #expect(defaults.object(forKey: key) as? Bool == value)
        }
    }

    @Test func explicitToggleCountsAsPriorInstallEvidence() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: "micMuteEnabled")

        ExtensionDefaultsMigration.migrate(defaults: defaults)

        for key in knownDefaultsKeys {
            #expect(defaults.object(forKey: key) is Bool)
        }
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "ExtensionRegistryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
