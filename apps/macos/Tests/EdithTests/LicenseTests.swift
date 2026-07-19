import Foundation
import Testing

@testable import EdithKit

@Suite struct LicenseTests {
    @Test func formatsLicenseKey() {
        #expect(
            LicenseKeyFormatting.format("edith-abcd1234 efgh-5678")
                == "EDITH-ABCD-1234-EFGH-5678")
        #expect(LicenseKeyFormatting.format("abcd1234efgh5678extra") == "EDITH-ABCD-1234-EFGH-5678")
        #expect(
            LicenseKeyFormatting.format("EDITH-EDITH-0ADA-AE18-6FB9-2097")
                == "EDITH-0ADA-AE18-6FB9-2097")
        #expect(LicenseKeyFormatting.isComplete("EDITH-ABCD-1234-EFGH-5678"))
    }

    @Test func masksAllButLastGroup() {
        #expect(
            LicenseKeyFormatting.masked("EDITH-ABCD-1234-EFGH-5678")
                == "EDITH-****-****-****-5678")
    }

    @Test func stateStoresKeyOnlyInKeyStoreAndMirrorsPresentationState() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let keyStore = InMemoryLicenseKeyStore()
        let state = LicenseState(keyStore: keyStore, defaults: defaults)

        try state.activate(key: "EDITH-ABCD-1234-EFGH-5678", label: "Personal")

        #expect(try state.licenseKey() == "EDITH-ABCD-1234-EFGH-5678")
        #expect(defaults.bool(forKey: LicenseState.activatedKey))
        #expect(defaults.string(forKey: LicenseState.labelKey) == "Personal")
        #expect(
            !defaults.dictionaryRepresentation().values.contains { value in
                value as? String == "EDITH-ABCD-1234-EFGH-5678"
            })

        try state.deactivate()

        #expect(try state.licenseKey() == nil)
        #expect(defaults.object(forKey: LicenseState.activatedKey) == nil)
        #expect(defaults.object(forKey: LicenseState.labelKey) == nil)
    }

    @Test func fileStoreRoundTripsKeyAndReceipt() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LicenseTests.\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileLicenseKeyStore(directory: directory)

        #expect(try store.readKey() == nil)
        #expect(try store.readReceipt() == nil)

        try store.writeKey("EDITH-ABCD-1234-EFGH-5678")
        try store.writeReceipt("signed-receipt")

        #expect(try store.readKey() == "EDITH-ABCD-1234-EFGH-5678")
        #expect(try store.readReceipt() == "signed-receipt")
        let keyPath = directory.appendingPathComponent(FileLicenseKeyStore.keyFilename).path
        let permissions =
            try FileManager.default.attributesOfItem(atPath: keyPath)[
                .posixPermissions] as? Int
        #expect(permissions == 0o600)

        try store.deleteKey()
        try store.deleteReceipt()
        try store.deleteKey()

        #expect(try store.readKey() == nil)
        #expect(try store.readReceipt() == nil)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "LicenseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

private final class InMemoryLicenseKeyStore: LicenseKeyStoring {
    private var key: String?
    private var receipt: String?

    func readKey() throws -> String? {
        key
    }

    func writeKey(_ key: String) throws {
        self.key = key
    }

    func deleteKey() throws {
        key = nil
    }

    func readReceipt() throws -> String? {
        receipt
    }

    func writeReceipt(_ receipt: String) throws {
        self.receipt = receipt
    }

    func deleteReceipt() throws {
        receipt = nil
    }
}
