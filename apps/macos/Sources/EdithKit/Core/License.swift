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

    public init(ok: Bool, label: String, machinesUsed: Int, maxMachines: Int) {
        self.ok = ok
        self.label = label
        self.machinesUsed = machinesUsed
        self.maxMachines = maxMachines
    }
}

public struct LicenseVerificationResponse: Codable, Equatable {
    public let ok: Bool

    public init(ok: Bool) {
        self.ok = ok
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

    public func verify(key: String, hardwareUuid: String) async throws -> Bool {
        let payload = VerificationPayload(key: key, hardwareUuid: hardwareUuid)
        let (data, response) = try await send(path: "verify", payload: payload)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(LicenseVerificationResponse.self, from: data).ok
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
}

public enum LicenseKeychainError: Error, Equatable {
    case unexpectedData
    case status(OSStatus)
}

public struct KeychainLicenseKeyStore: LicenseKeyStoring {
    public static let service = "com.pulkit.edith.license"
    public static let account = "license-key"

    public init() {}

    public func readKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw LicenseKeychainError.status(status) }
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw LicenseKeychainError.unexpectedData
        }
        return key
    }

    public func writeKey(_ key: String) throws {
        let data = Data(key.utf8)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw LicenseKeychainError.status(updateStatus)
        }
        var item = baseQuery
        item[kSecValueData as String] = data
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw LicenseKeychainError.status(addStatus) }
    }

    public func deleteKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LicenseKeychainError.status(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecAttrSynchronizable as String: false,
        ]
    }
}

public enum LicenseGateDecision: Equatable {
    case proceed
    case gate
}

public func licenseGateDecision(hasKey: Bool, licenseActivated: Bool) -> LicenseGateDecision {
    hasKey && licenseActivated ? .proceed : .gate
}

public final class LicenseState {
    public static let activatedKey = "licenseActivated"
    public static let labelKey = "licenseLabel"

    private let keyStore: any LicenseKeyStoring
    private let defaults: UserDefaults

    public init(
        keyStore: any LicenseKeyStoring = KeychainLicenseKeyStore(),
        defaults: UserDefaults = SharedDefaults.store
    ) {
        self.keyStore = keyStore
        self.defaults = defaults
    }

    public var isActivated: Bool { defaults.bool(forKey: Self.activatedKey) }
    public var label: String? { defaults.string(forKey: Self.labelKey) }

    public func licenseKey() throws -> String? {
        try keyStore.readKey()
    }

    public func gateDecision() throws -> LicenseGateDecision {
        try licenseGateDecision(hasKey: keyStore.readKey() != nil, licenseActivated: isActivated)
    }

    public func activate(key: String, label: String) throws {
        try keyStore.writeKey(key)
        defaults.set(label, forKey: Self.labelKey)
        defaults.set(true, forKey: Self.activatedKey)
    }

    public func markVerificationFailed() {
        defaults.set(false, forKey: Self.activatedKey)
    }

    public func deactivate() throws {
        try keyStore.deleteKey()
        defaults.removeObject(forKey: Self.activatedKey)
        defaults.removeObject(forKey: Self.labelKey)
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
