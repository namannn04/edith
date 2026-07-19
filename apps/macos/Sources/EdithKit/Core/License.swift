import Foundation
import IOKit
import Security

public protocol LicenseTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: LicenseTransport {
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request, delegate: nil)
        guard let response = response as? HTTPURLResponse else {
            throw LicenseClientError.invalidResponse
        }
        return (data, response)
    }
}

public enum LicenseClientError: Error, Equatable {
    case seatLimitReached
    case invalidKey
    case invalidResponse
    case server(statusCode: Int)
}

public struct LicenseActivationResponse: Codable, Equatable {
    public let ok: Bool
    public let label: String
    public let machinesUsed: Int
    public let maxMachines: Int
    public let receipt: String?

    public init(
        ok: Bool, label: String, machinesUsed: Int, maxMachines: Int, receipt: String? = nil
    ) {
        self.ok = ok
        self.label = label
        self.machinesUsed = machinesUsed
        self.maxMachines = maxMachines
        self.receipt = receipt
    }
}

public struct LicenseVerificationResponse: Codable, Equatable {
    public let ok: Bool
    public let receipt: String?

    public init(ok: Bool, receipt: String? = nil) {
        self.ok = ok
        self.receipt = receipt
    }
}

public struct LicenseClient {
    public static let baseURL = URL(string: "https://edith.pulkit.page/api/v1")!

    private let transport: any LicenseTransport
    private let baseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        transport: any LicenseTransport = URLSession.shared,
        baseURL: URL = LicenseClient.baseURL
    ) {
        self.transport = transport
        self.baseURL = baseURL
    }

    public func activate(key: String, hardwareUuid: String, hostname: String? = nil) async throws
        -> LicenseActivationResponse
    {
        let payload = ActivationPayload(key: key, hardwareUuid: hardwareUuid, hostname: hostname)
        let (data, response) = try await send(path: "activate", payload: payload)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(LicenseActivationResponse.self, from: data)
        } catch {
            throw LicenseClientError.invalidResponse
        }
    }

    public func verify(key: String, hardwareUuid: String) async throws
        -> LicenseVerificationResponse
    {
        let payload = VerificationPayload(key: key, hardwareUuid: hardwareUuid)
        let (data, response) = try await send(path: "verify", payload: payload)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(LicenseVerificationResponse.self, from: data)
        } catch {
            throw LicenseClientError.invalidResponse
        }
    }

    private func send<Payload: Encodable>(path: String, payload: Payload) async throws
        -> (Data, HTTPURLResponse)
    {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)
        return try await transport.data(for: request)
    }

    private func validate(response: HTTPURLResponse, data: Data) throws {
        guard !(200..<300).contains(response.statusCode) else { return }
        if response.statusCode == 403,
            (try? decoder.decode(APIErrorPayload.self, from: data).error)
                == "license_limit_reached"
        {
            throw LicenseClientError.seatLimitReached
        }
        if (400..<500).contains(response.statusCode) {
            throw LicenseClientError.invalidKey
        }
        throw LicenseClientError.server(statusCode: response.statusCode)
    }
}

private struct ActivationPayload: Codable {
    let key: String
    let hardwareUuid: String
    let hostname: String?
}

private struct VerificationPayload: Codable {
    let key: String
    let hardwareUuid: String
}

private struct APIErrorPayload: Codable {
    let error: String
}

public protocol LicenseKeyStoring {
    func readKey() throws -> String?
    func writeKey(_ key: String) throws
    func deleteKey() throws
    func readReceipt() throws -> String?
    func writeReceipt(_ receipt: String) throws
    func deleteReceipt() throws
}

public enum LicenseKeychainError: Error, Equatable {
    case unexpectedData
    case status(OSStatus)
}

public struct KeychainLicenseKeyStore: LicenseKeyStoring {
    public static let service = "com.pulkit.edith.license"
    public static let keyAccount = "license-key"
    public static let receiptAccount = "license-receipt"

    public init() {}

    public func readKey() throws -> String? {
        try readValue(account: Self.keyAccount)
    }

    public func writeKey(_ key: String) throws {
        try writeValue(key, account: Self.keyAccount)
    }

    public func deleteKey() throws {
        try deleteValue(account: Self.keyAccount)
    }

    public func readReceipt() throws -> String? {
        try readValue(account: Self.receiptAccount)
    }

    public func writeReceipt(_ receipt: String) throws {
        try writeValue(receipt, account: Self.receiptAccount)
    }

    public func deleteReceipt() throws {
        try deleteValue(account: Self.receiptAccount)
    }

    private func readValue(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw LicenseKeychainError.status(status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw LicenseKeychainError.unexpectedData
        }
        return value
    }

    private func writeValue(_ value: String, account: String) throws {
        let query = baseQuery(account: account)
        let data = Data(value.utf8)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw LicenseKeychainError.status(updateStatus)
        }
        var item = query
        item[kSecValueData as String] = data
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw LicenseKeychainError.status(addStatus) }
    }

    private func deleteValue(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LicenseKeychainError.status(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
        ]
    }
}

public enum LicenseGateDecision: Equatable {
    case proceed
    case proceedNeedsRefresh
    case gate
}

public func licenseGateDecision(hasKey: Bool, licenseActivated: Bool) -> LicenseGateDecision {
    hasKey && licenseActivated ? .proceedNeedsRefresh : .gate
}

public enum OfflineLicenseStatus: Equatable {
    case valid
    case needsRefresh
    case noKey
    case invalid
}

public enum LicenseStateError: Error, Equatable {
    case invalidReceipt
}

public final class LicenseState {
    public static let activatedKey = "licenseActivated"
    public static let labelKey = "licenseLabel"

    private let keyStore: any LicenseKeyStoring
    private let defaults: UserDefaults
    private let receiptVerifier: LicenseReceiptVerifier
    private let machineIdentifier: () -> String?

    public init(
        keyStore: any LicenseKeyStoring = KeychainLicenseKeyStore(),
        defaults: UserDefaults = SharedDefaults.store,
        receiptVerifier: LicenseReceiptVerifier = LicenseReceiptVerifier(),
        machineIdentifier: @escaping () -> String? = hardwareUUID
    ) {
        self.keyStore = keyStore
        self.defaults = defaults
        self.receiptVerifier = receiptVerifier
        self.machineIdentifier = machineIdentifier
    }

    public var isActivated: Bool { defaults.bool(forKey: Self.activatedKey) }
    public var label: String? { defaults.string(forKey: Self.labelKey) }

    public func licenseKey() throws -> String? {
        try keyStore.readKey()
    }

    public func currentReceiptValid() -> Bool {
        guard (try? keyStore.readKey()) != nil,
            let receipt = try? keyStore.readReceipt(),
            let machine = machineIdentifier()
        else {
            return false
        }
        return receiptVerifier.verify(receipt: receipt, expectedMachine: machine)
    }

    public func offlineStatus() throws -> OfflineLicenseStatus {
        guard try keyStore.readKey() != nil else { return .noKey }
        guard let receipt = try keyStore.readReceipt() else {
            return isActivated ? .needsRefresh : .invalid
        }
        guard let machine = machineIdentifier() else { return .invalid }
        switch receiptVerifier.validation(receipt: receipt, expectedMachine: machine) {
        case .valid:
            return .valid
        case .expired:
            return .needsRefresh
        case .invalid:
            return .invalid
        }
    }

    public func gateDecision() throws -> LicenseGateDecision {
        switch try offlineStatus() {
        case .valid:
            return .proceed
        case .needsRefresh:
            return .proceedNeedsRefresh
        case .noKey, .invalid:
            return .gate
        }
    }

    public func activate(key: String, label: String, receipt: String? = nil) throws {
        if let receipt {
            _ = try verifiedReceipt(receipt)
        }
        try keyStore.writeKey(key)
        if let receipt {
            try keyStore.writeReceipt(receipt)
        } else {
            try keyStore.deleteReceipt()
        }
        defaults.set(label, forKey: Self.labelKey)
        defaults.set(true, forKey: Self.activatedKey)
    }

    public func recordSuccessfulVerification(receipt: String?) throws {
        if let receipt {
            let payload = try verifiedReceipt(receipt)
            try keyStore.writeReceipt(receipt)
            defaults.set(payload.label, forKey: Self.labelKey)
        }
        defaults.set(true, forKey: Self.activatedKey)
    }

    public func deactivate() throws {
        var deletionError: Error?
        do {
            try keyStore.deleteKey()
        } catch {
            deletionError = error
        }
        do {
            try keyStore.deleteReceipt()
        } catch {
            if deletionError == nil { deletionError = error }
        }
        defaults.removeObject(forKey: Self.activatedKey)
        defaults.removeObject(forKey: Self.labelKey)
        if let deletionError { throw deletionError }
    }

    private func verifiedReceipt(_ receipt: String) throws -> LicenseReceipt {
        guard let machine = machineIdentifier(),
            let payload = receiptVerifier.verifiedReceipt(
                receipt: receipt, expectedMachine: machine)
        else {
            throw LicenseStateError.invalidReceipt
        }
        return payload
    }
}

public enum LicenseKeyFormatting {
    public static func format(_ input: String) -> String {
        let compact = input.uppercased().filter { $0.isLetter || $0.isNumber }
        let body = compact.hasPrefix("EDITH") ? String(compact.dropFirst(5)) : compact
        let limited = String(body.prefix(16))
        let groups = stride(from: 0, to: limited.count, by: 4).map { start in
            let lower = limited.index(limited.startIndex, offsetBy: start)
            let upper = limited.index(lower, offsetBy: min(4, limited.count - start))
            return String(limited[lower..<upper])
        }
        return (["EDITH"] + groups).joined(separator: "-")
    }

    public static func isComplete(_ key: String) -> Bool {
        format(key).count == 25
    }

    public static func masked(_ key: String) -> String {
        let formatted = format(key)
        guard isComplete(formatted), let suffix = formatted.split(separator: "-").last else {
            return "EDITH-****-****-****-****"
        }
        return "EDITH-****-****-****-\(suffix)"
    }
}

public func hardwareUUID() -> String? {
    let service = IOServiceGetMatchingService(
        kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    guard service != IO_OBJECT_NULL else { return nil }
    defer { IOObjectRelease(service) }
    return IORegistryEntryCreateCFProperty(
        service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0
    )?.takeRetainedValue() as? String
}
