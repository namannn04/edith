import Testing

@testable import EdithKit

@Suite struct FeatureGatesTests {
    @Test func presenterInactiveWhenExtensionDisabled() {
        #expect(!FeatureGates.presenterActive(enabled: false, manual: true, autoActive: true))
        #expect(!FeatureGates.presenterActive(enabled: false, manual: true, autoActive: false))
        #expect(!FeatureGates.presenterActive(enabled: false, manual: false, autoActive: true))
    }

    @Test func presenterActiveFromManualOrAuto() {
        #expect(FeatureGates.presenterActive(enabled: true, manual: true, autoActive: false))
        #expect(FeatureGates.presenterActive(enabled: true, manual: false, autoActive: true))
        #expect(!FeatureGates.presenterActive(enabled: true, manual: false, autoActive: false))
    }

    @Test func detectorNeedsBothMasterAndAutoToggles() {
        #expect(FeatureGates.presenterDetectorWanted(presenterEnabled: true, autoEnabled: true))
        #expect(!FeatureGates.presenterDetectorWanted(presenterEnabled: true, autoEnabled: false))
        #expect(!FeatureGates.presenterDetectorWanted(presenterEnabled: false, autoEnabled: true))
    }

    @Test func preventSleepClearsWhenSystemDisabled() {
        #expect(!FeatureGates.preventSleepPersisted(systemOn: false, current: true))
        #expect(FeatureGates.preventSleepPersisted(systemOn: true, current: true))
        #expect(!FeatureGates.preventSleepPersisted(systemOn: true, current: false))
    }
}
