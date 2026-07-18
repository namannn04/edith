import Foundation
import Testing

@testable import EdithKit

@Suite struct OnboardingTests {
    @Test func freshInstallShowsOnboarding() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let freshInstall = ExtensionDefaultsMigration.migrate(defaults: defaults)

        #expect(freshInstall)
        #expect(defaults.bool(forKey: ExtensionDefaultsMigration.freshInstallKey))
        #expect(OnboardingFlow.shouldShowOnboarding(defaults: defaults))
        #expect(!defaults.bool(forKey: OnboardingFlow.completionKey))
    }

    @Test func priorInstallSkipsOnboarding() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "hasPromptedPermissions")

        let freshInstall = ExtensionDefaultsMigration.migrate(defaults: defaults)

        #expect(!freshInstall)
        #expect(!defaults.bool(forKey: ExtensionDefaultsMigration.freshInstallKey))
        #expect(defaults.bool(forKey: OnboardingFlow.completionKey))
        #expect(!OnboardingFlow.shouldShowOnboarding(defaults: defaults))
    }

    @Test func existingMigrationMarkerSkipsNewTour() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: ExtensionDefaultsMigration.markerKey)

        let freshInstall = ExtensionDefaultsMigration.migrate(defaults: defaults)

        #expect(!freshInstall)
        #expect(defaults.bool(forKey: OnboardingFlow.completionKey))
        #expect(!OnboardingFlow.shouldShowOnboarding(defaults: defaults))
    }

    @Test func explicitExtensionToggleSkipsOnboarding() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: "clipboardEnabled")

        ExtensionDefaultsMigration.migrate(defaults: defaults)

        #expect(defaults.bool(forKey: OnboardingFlow.completionKey))
        #expect(!OnboardingFlow.shouldShowOnboarding(defaults: defaults))
    }

    @Test func permissionsDedupeAndExcludeGrantedValues() {
        let selectedIDs: Set<String> = ["system", "clipboard"]
        let permissions = OnboardingFlow.missingPermissions(
            selectedIDs: selectedIDs,
            granted: [.accessibility: false, .inputMonitoring: true])

        #expect(
            permissions
                == [OnboardingPermission(permission: .accessibility, required: true)])
    }

    @Test func skipEnablesNothing() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        OnboardingFlow.skip(defaults: defaults)

        #expect(defaults.bool(forKey: OnboardingFlow.completionKey))
        for entry in ExtensionRegistry.entries {
            #expect(defaults.object(forKey: entry.defaultsKey) == nil)
            #expect(defaults.object(forKey: OnboardingFlow.seenKey(for: entry)) == nil)
        }
    }

    @Test func finishWritesExactlySelectedExtensionKeys() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let selectedIDs: Set<String> = ["usage", "notchShelf"]

        OnboardingFlow.finish(selectedIDs: selectedIDs, defaults: defaults)

        #expect(defaults.bool(forKey: OnboardingFlow.completionKey))
        for entry in ExtensionRegistry.entries {
            if selectedIDs.contains(entry.id) {
                #expect(defaults.object(forKey: entry.defaultsKey) as? Bool == true)
                #expect(
                    defaults.object(forKey: OnboardingFlow.seenKey(for: entry)) as? Bool == true)
            } else {
                #expect(defaults.object(forKey: entry.defaultsKey) == nil)
                #expect(defaults.object(forKey: OnboardingFlow.seenKey(for: entry)) == nil)
            }
        }
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "OnboardingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
