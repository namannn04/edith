import Testing

@testable import EdithCore

@Suite struct PlatformCapabilitiesTests {
    @Test func macOSSupportsEveryDeclaredCapability() {
        for capability in PlatformCapability.allCases {
            #expect(PlatformCapabilities.macOS.state(for: capability).isSupported)
        }
    }

    @Test func ubuntuReportsPortalCapabilitiesAsSupported() {
        #expect(PlatformCapabilities.ubuntu.state(for: .globalShortcuts).isSupported)
        #expect(PlatformCapabilities.ubuntu.state(for: .screenColorSampling).isSupported)
        #expect(PlatformCapabilities.ubuntu.state(for: .clipboardHistory).isSupported)
    }

    @Test func ubuntuBlocksExtensionsThatNeedShellIntegration() {
        let availability = PlatformCapabilities.ubuntu.availability(
            required: [.windowDimming], optional: [])

        #expect(availability == .unavailable([.windowDimming]))
    }

    @Test func missingOptionalCapabilitiesDegradeAnExtension() {
        let availability = PlatformCapabilities.ubuntu.availability(
            required: [.clipboardHistory], optional: [.globalPaste])

        #expect(availability == .degraded([.globalPaste]))
    }
}
