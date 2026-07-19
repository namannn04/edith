import Foundation
import Testing

@testable import EdithKit

@Suite struct LicenseTests {
    @Test func formatsLicenseKey() {
        #expect(
            LicenseKeyFormatting.format("edith-abcd1234 efgh-5678")
                == "EDITH-ABCD-1234-EFGH-5678")
        #expect(LicenseKeyFormatting.format("abcd1234efgh5678extra") == "EDITH-ABCD-1234-EFGH-5678")
        #expect(LicenseKeyFormatting.isComplete("EDITH-ABCD-1234-EFGH-5678"))
    }

    @Test func masksAllButLastGroup() {
        #expect(
            LicenseKeyFormatting.masked("EDITH-ABCD-1234-EFGH-5678")
                == "EDITH-****-****-****-5678")
    }

    @Test func activationDecodesSuccessWithoutPersisting() async throws {
        let transport = StubLicenseTransport(
            statusCode: 200,
            body: #"{"ok":true,"label":"Personal","machinesUsed":1,"maxMachines":3}"#
        )
        let client = LicenseClient(
            transport: transport,
            baseURL: URL(string: "https://license.test/api/v1")!
        )

        let response = try await client.activate(
            key: "EDITH-ABCD-1234-EFGH-5678",
            hardwareUuid: "hardware-id",
            hostname: "Test Mac"
        )

        #expect(response.label == "Personal")
        #expect(response.machinesUsed == 1)
        #expect(response.maxMachines == 3)
        let request = try #require(transport.request)
        #expect(request.url?.absoluteString == "https://license.test/api/v1/activate")
        let body = try #require(request.httpBody)
        let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(payload["key"] as? String == "EDITH-ABCD-1234-EFGH-5678")
        #expect(payload["hardwareUuid"] as? String == "hardware-id")
        #expect(payload["hostname"] as? String == "Test Mac")
    }

    @Test func verifyReturnsDefinitiveFalse() async throws {
        let transport = StubLicenseTransport(statusCode: 200, body: #"{"ok":false}"#)
        let client = LicenseClient(transport: transport)

        let verified = try await client.verify(key: "key", hardwareUuid: "machine")

        #expect(!verified)
    }

    @Test func activationMapsSeatLimitError() async {
        let transport = StubLicenseTransport(
            statusCode: 403, body: #"{"error":"license_limit_reached"}"#)
        let client = LicenseClient(transport: transport)

        do {
            _ = try await client.activate(key: "key", hardwareUuid: "machine")
            Issue.record("Expected seat limit error")
        } catch {
            #expect(error as? LicenseClientError == .seatLimitReached)
        }
    }

    @Test func activationMapsOtherClientErrorsToInvalidKey() async {
        let transport = StubLicenseTransport(statusCode: 401, body: #"{"error":"inactive"}"#)
        let client = LicenseClient(transport: transport)

        do {
            _ = try await client.activate(key: "key", hardwareUuid: "machine")
            Issue.record("Expected invalid key error")
        } catch {
            #expect(error as? LicenseClientError == .invalidKey)
        }
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

    @Test func gateProceedsOnlyWithKeyAndActivatedMirror() {
        #expect(licenseGateDecision(hasKey: true, licenseActivated: true) == .proceed)
        #expect(licenseGateDecision(hasKey: false, licenseActivated: true) == .gate)
        #expect(licenseGateDecision(hasKey: true, licenseActivated: false) == .gate)
        #expect(licenseGateDecision(hasKey: false, licenseActivated: false) == .gate)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "LicenseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

private final class StubLicenseTransport: LicenseTransport {
    private let statusCode: Int
    private let responseData: Data
    private(set) var request: URLRequest?

    init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        responseData = Data(body.utf8)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (responseData, response)
    }
}

private final class InMemoryLicenseKeyStore: LicenseKeyStoring {
    private var key: String?

    func readKey() throws -> String? {
        key
    }

    func writeKey(_ key: String) throws {
        self.key = key
    }

    func deleteKey() throws {
        key = nil
    }
}
