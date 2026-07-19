import Foundation
import Testing

@testable import EdithKit

@Suite struct LicenseReceiptTests {
    private let machine = "hardware-id"
    private let signature = Data("test-signature".utf8)

    @Test func verifiesSignatureAndParsesPayload() throws {
        let payload = LicenseReceipt(
            machine: machine,
            label: "Personal",
            issuedAt: 1_700_000_000,
            expiresAt: 1_800_000_000,
            keyLast4: "5678"
        )
        let fixture = try makeFixture(payload)
        let verifier = makeVerifier(payloadData: fixture.payloadData, now: 1_750_000_000)

        #expect(verifier.verify(receipt: fixture.receipt, expectedMachine: machine))
        #expect(
            verifier.verifiedReceipt(receipt: fixture.receipt, expectedMachine: machine) == payload)
    }

    @Test func rejectsMalformedReceipts() {
        let verifier = LicenseReceiptVerifier(
            publicKey: ExactSignatureVerifier(payload: Data(), signature: signature),
            now: { Date(timeIntervalSince1970: 1_750_000_000) }
        )

        #expect(!verifier.verify(receipt: "", expectedMachine: machine))
        #expect(!verifier.verify(receipt: "abc", expectedMachine: machine))
        #expect(!verifier.verify(receipt: "abc.def.ghi", expectedMachine: machine))
        #expect(!verifier.verify(receipt: "abc=.def", expectedMachine: machine))
    }

    @Test func embeddedKeyRejectsForgedSignature() throws {
        let payload = LicenseReceipt(
            machine: machine,
            label: "Personal",
            issuedAt: 1_700_000_000,
            expiresAt: 1_800_000_000,
            keyLast4: "5678"
        )
        let payloadData = try JSONEncoder().encode(payload)
        let receipt = "\(base64URL(payloadData)).\(base64URL(Data(repeating: 0, count: 64)))"
        let verifier = LicenseReceiptVerifier(now: {
            Date(timeIntervalSince1970: 1_750_000_000)
        })

        #expect(!verifier.verify(receipt: receipt, expectedMachine: machine))
    }

    @Test func rejectsWrongMachine() throws {
        let payload = LicenseReceipt(
            machine: machine,
            label: "Personal",
            issuedAt: 1_700_000_000,
            expiresAt: 1_800_000_000,
            keyLast4: "5678"
        )
        let fixture = try makeFixture(payload)
        let verifier = makeVerifier(payloadData: fixture.payloadData, now: 1_750_000_000)

        #expect(!verifier.verify(receipt: fixture.receipt, expectedMachine: "other-machine"))
        #expect(
            verifier.validation(receipt: fixture.receipt, expectedMachine: "other-machine")
                == .invalid)
    }

    @Test func rejectsExpiredReceipt() throws {
        let payload = LicenseReceipt(
            machine: machine,
            label: "Personal",
            issuedAt: 1_600_000_000,
            expiresAt: 1_700_000_000,
            keyLast4: "5678"
        )
        let fixture = try makeFixture(payload)
        let verifier = makeVerifier(payloadData: fixture.payloadData, now: 1_750_000_000)

        #expect(!verifier.verify(receipt: fixture.receipt, expectedMachine: machine))
        #expect(
            verifier.validation(receipt: fixture.receipt, expectedMachine: machine) == .expired)
    }

    @Test func rejectsTamperedPayload() throws {
        let payload = LicenseReceipt(
            machine: machine,
            label: "Personal",
            issuedAt: 1_700_000_000,
            expiresAt: 1_800_000_000,
            keyLast4: "5678"
        )
        let fixture = try makeFixture(payload)
        let tamperedPayload = LicenseReceipt(
            machine: machine,
            label: "Business",
            issuedAt: payload.issuedAt,
            expiresAt: payload.expiresAt,
            keyLast4: payload.keyLast4
        )
        let tamperedData = try JSONEncoder().encode(tamperedPayload)
        let tamperedReceipt = "\(base64URL(tamperedData)).\(base64URL(signature))"
        let verifier = makeVerifier(payloadData: fixture.payloadData, now: 1_750_000_000)

        #expect(!verifier.verify(receipt: tamperedReceipt, expectedMachine: machine))
        #expect(
            verifier.validation(receipt: tamperedReceipt, expectedMachine: machine) == .invalid)
    }

    @Test func stateRequiresKeyAndValidReceiptForCurrentValidity() throws {
        let payload = LicenseReceipt(
            machine: machine,
            label: "Personal",
            issuedAt: 1_700_000_000,
            expiresAt: 1_800_000_000,
            keyLast4: "5678"
        )
        let fixture = try makeFixture(payload)
        let store = ReceiptLicenseStore()
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = LicenseState(
            keyStore: store,
            defaults: defaults,
            receiptVerifier: makeVerifier(
                payloadData: fixture.payloadData, now: 1_750_000_000),
            machineIdentifier: { self.machine }
        )

        try state.activate(key: "EDITH-ABCD-1234-EFGH-5678", label: "Personal")
        #expect(!state.currentReceiptValid())
        #expect(try state.offlineStatus() == .needsRefresh)

        try state.recordSuccessfulVerification(receipt: fixture.receipt)
        #expect(state.currentReceiptValid())
        #expect(try state.gateDecision() == .proceed)

        try state.deactivate()
        #expect(!state.currentReceiptValid())
        #expect(try state.offlineStatus() == .noKey)
    }

    @Test func stateAllowsExpiredReceiptOnlyAsNeedsRefresh() throws {
        let payload = LicenseReceipt(
            machine: machine,
            label: "Personal",
            issuedAt: 1_600_000_000,
            expiresAt: 1_700_000_000,
            keyLast4: "5678"
        )
        let fixture = try makeFixture(payload)
        let store = ReceiptLicenseStore(key: "key", receipt: fixture.receipt)
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = LicenseState(
            keyStore: store,
            defaults: defaults,
            receiptVerifier: makeVerifier(
                payloadData: fixture.payloadData, now: 1_750_000_000),
            machineIdentifier: { self.machine }
        )

        #expect(!state.currentReceiptValid())
        #expect(try state.offlineStatus() == .needsRefresh)
        #expect(try state.gateDecision() == .proceedNeedsRefresh)
    }

    @Test func stateGatesTamperedReceipt() throws {
        let payload = LicenseReceipt(
            machine: machine,
            label: "Personal",
            issuedAt: 1_700_000_000,
            expiresAt: 1_800_000_000,
            keyLast4: "5678"
        )
        let fixture = try makeFixture(payload)
        let tamperedPayload = LicenseReceipt(
            machine: machine,
            label: "Business",
            issuedAt: payload.issuedAt,
            expiresAt: payload.expiresAt,
            keyLast4: payload.keyLast4
        )
        let tamperedData = try JSONEncoder().encode(tamperedPayload)
        let tamperedReceipt = "\(base64URL(tamperedData)).\(base64URL(signature))"
        let store = ReceiptLicenseStore(key: "key", receipt: tamperedReceipt)
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = LicenseState(
            keyStore: store,
            defaults: defaults,
            receiptVerifier: makeVerifier(
                payloadData: fixture.payloadData, now: 1_750_000_000),
            machineIdentifier: { self.machine }
        )

        #expect(!state.currentReceiptValid())
        #expect(try state.offlineStatus() == .invalid)
        #expect(try state.gateDecision() == .gate)
    }

    private func makeFixture(_ payload: LicenseReceipt) throws -> (
        receipt: String, payloadData: Data
    ) {
        let payloadData = try JSONEncoder().encode(payload)
        return ("\(base64URL(payloadData)).\(base64URL(signature))", payloadData)
    }

    private func makeVerifier(payloadData: Data, now: TimeInterval) -> LicenseReceiptVerifier {
        LicenseReceiptVerifier(
            publicKey: ExactSignatureVerifier(payload: payloadData, signature: signature),
            now: { Date(timeIntervalSince1970: now) }
        )
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "LicenseReceiptTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

private struct ExactSignatureVerifier: LicenseSignatureVerifying {
    let payload: Data
    let signature: Data

    func isValidSignature(_ signature: Data, for data: Data) -> Bool {
        signature == self.signature && data == payload
    }
}

private final class ReceiptLicenseStore: LicenseKeyStoring {
    private var key: String?
    private var receipt: String?

    init(key: String? = nil, receipt: String? = nil) {
        self.key = key
        self.receipt = receipt
    }

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
