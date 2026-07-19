import Foundation
import IOKit

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
    case machineLimitReached(machinesUsed: Int, maxMachines: Int)
    case invalidKey
    case invalidResponse
    case server(statusCode: Int)
}

public struct LicenseClient {
    public static let baseURL = URL(string: "https://edith.pulkit.page/api")!

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

    private func validate(response: HTTPURLResponse, data: Data) throws {
        guard !(200..<300).contains(response.statusCode) else { return }
        if response.statusCode == 403,
            let payload = try? decoder.decode(APIErrorPayload.self, from: data),
            payload.error == "license_limit_reached" || payload.error == "machine_limit_reached"
        {
            if let machinesUsed = payload.machinesUsed, let maxMachines = payload.maxMachines {
                throw LicenseClientError.machineLimitReached(
                    machinesUsed: machinesUsed, maxMachines: maxMachines)
            }
            throw LicenseClientError.seatLimitReached
        }
        if response.statusCode == 404 || response.statusCode == 429 {
            throw LicenseClientError.server(statusCode: response.statusCode)
        }
        if (400..<500).contains(response.statusCode) {
            throw LicenseClientError.invalidKey
        }
        throw LicenseClientError.server(statusCode: response.statusCode)
    }
}

public struct LicenseChallengeResponse: Codable, Equatable {
    public let challengeId: String
    public let nonce: String
    public let expiresAt: String

    public init(challengeId: String, nonce: String, expiresAt: String) {
        self.challengeId = challengeId
        self.nonce = nonce
        self.expiresAt = expiresAt
    }
}

public struct LicenseActivationResponse: Codable, Equatable {
    public let ok: Bool
    public let planId: String
    public let machinesUsed: Int
    public let maxMachines: Int
    public let entitlement: String
    public let refreshCredential: String
    public let accessToken: String
    public let accessTokenExpiresAt: String

    public init(
        ok: Bool, planId: String, machinesUsed: Int, maxMachines: Int, entitlement: String,
        refreshCredential: String, accessToken: String, accessTokenExpiresAt: String
    ) {
        self.ok = ok
        self.planId = planId
        self.machinesUsed = machinesUsed
        self.maxMachines = maxMachines
        self.entitlement = entitlement
        self.refreshCredential = refreshCredential
        self.accessToken = accessToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
    }
}

public struct LicenseRefreshResponse: Codable, Equatable {
    public let ok: Bool
    public let entitlement: String
    public let refreshCredential: String
    public let accessToken: String
    public let accessTokenExpiresAt: String

    public init(
        ok: Bool, entitlement: String, refreshCredential: String, accessToken: String,
        accessTokenExpiresAt: String
    ) {
        self.ok = ok
        self.entitlement = entitlement
        self.refreshCredential = refreshCredential
        self.accessToken = accessToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
    }
}

public struct LicenseDeactivationResponse: Codable, Equatable {
    public let ok: Bool

    public init(ok: Bool) {
        self.ok = ok
    }
}

extension LicenseClient {
    public func activationChallenge(
        licenseKey: String, deviceId: String, devicePublicKey: String, purpose: String? = nil
    ) async throws -> LicenseChallengeResponse {
        try await request(
            path: "activation/challenge",
            payload: ActivationChallengePayload(
                licenseKey: licenseKey, deviceId: deviceId, devicePublicKey: devicePublicKey,
                purpose: purpose))
    }

    public func activate(
        licenseKey: String, challengeId: String, nonce: String, deviceId: String,
        devicePublicKey: String, signature: String, appVersion: String, deviceName: String? = nil,
        hardwareUuidDigest: String? = nil
    ) async throws -> LicenseActivationResponse {
        try await request(
            path: "activation",
            payload: ActivationPayload(
                licenseKey: licenseKey, challengeId: challengeId, nonce: nonce, deviceId: deviceId,
                devicePublicKey: devicePublicKey, signature: signature, appVersion: appVersion,
                deviceName: deviceName, hardwareUuidDigest: hardwareUuidDigest))
    }

    public func refreshChallenge(
        deviceId: String, refreshCredential: String, purpose: String? = nil
    ) async throws -> LicenseChallengeResponse {
        try await request(
            path: "devices/refresh/challenge",
            payload: RefreshChallengePayload(
                deviceId: deviceId, refreshCredential: refreshCredential, purpose: purpose))
    }

    public func refresh(
        deviceId: String, challengeId: String, nonce: String, signature: String,
        appVersion: String
    ) async throws -> LicenseRefreshResponse {
        try await request(
            path: "devices/refresh",
            payload: RefreshPayload(
                deviceId: deviceId, challengeId: challengeId, nonce: nonce, signature: signature,
                appVersion: appVersion))
    }

    public func deactivate(
        deviceId: String, challengeId: String, nonce: String, signature: String
    ) async throws -> LicenseDeactivationResponse {
        try await request(
            path: "devices/deactivate",
            payload: DeactivationPayload(
                deviceId: deviceId, challengeId: challengeId, nonce: nonce, signature: signature))
    }

    private func request<Payload: Encodable, Response: Decodable>(
        path: String, payload: Payload
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)
        let (data, response) = try await transport.data(for: request)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw LicenseClientError.invalidResponse
        }
    }
}

private struct ActivationChallengePayload: Codable {
    let licenseKey: String
    let deviceId: String
    let devicePublicKey: String
    let purpose: String?
}

private struct ActivationPayload: Codable {
    let licenseKey: String
    let challengeId: String
    let nonce: String
    let deviceId: String
    let devicePublicKey: String
    let signature: String
    let appVersion: String
    let deviceName: String?
    let hardwareUuidDigest: String?
}

private struct RefreshChallengePayload: Codable {
    let deviceId: String
    let refreshCredential: String
    let purpose: String?
}

private struct RefreshPayload: Codable {
    let deviceId: String
    let challengeId: String
    let nonce: String
    let signature: String
    let appVersion: String
}

private struct DeactivationPayload: Codable {
    let deviceId: String
    let challengeId: String
    let nonce: String
    let signature: String
}

private struct APIErrorPayload: Codable {
    let error: String
    let machinesUsed: Int?
    let maxMachines: Int?
}

public protocol LicenseKeyStoring {
    func readKey() throws -> String?
    func writeKey(_ key: String) throws
    func deleteKey() throws
    func readReceipt() throws -> String?
    func writeReceipt(_ receipt: String) throws
    func deleteReceipt() throws
}

public struct FileLicenseKeyStore: LicenseKeyStoring {
    public static let keyFilename = "license-key"
    public static let receiptFilename = "license-receipt"

    private let keyURL: URL
    private let receiptURL: URL

    public init(directory: URL = AppData.supportDir) {
        keyURL = directory.appendingPathComponent(Self.keyFilename)
        receiptURL = directory.appendingPathComponent(Self.receiptFilename)
    }

    public func readKey() throws -> String? {
        try read(keyURL)
    }

    public func writeKey(_ key: String) throws {
        try write(key, to: keyURL)
    }

    public func deleteKey() throws {
        try delete(keyURL)
    }

    public func readReceipt() throws -> String? {
        try read(receiptURL)
    }

    public func writeReceipt(_ receipt: String) throws {
        try write(receipt, to: receiptURL)
    }

    public func deleteReceipt() throws {
        try delete(receiptURL)
    }

    private func read(_ url: URL) throws -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func write(_ value: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(value.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func delete(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

public final class LicenseState {
    public static let activatedKey = "licenseActivated"
    public static let labelKey = "licenseLabel"
    public static let nameKey = "licenseName"

    private let keyStore: any LicenseKeyStoring
    private let defaults: UserDefaults

    public init(
        keyStore: any LicenseKeyStoring = FileLicenseKeyStore(),
        defaults: UserDefaults = SharedDefaults.store
    ) {
        self.keyStore = keyStore
        self.defaults = defaults
    }

    public var isActivated: Bool { defaults.bool(forKey: Self.activatedKey) }
    public var label: String? { defaults.string(forKey: Self.labelKey) }
    public var name: String? { defaults.string(forKey: Self.nameKey) }

    public func licenseKey() throws -> String? {
        try keyStore.readKey()
    }

    public func activate(key: String, label: String, name: String? = nil) throws {
        try keyStore.writeKey(key)
        defaults.set(label, forKey: Self.labelKey)
        if let name, !name.isEmpty {
            defaults.set(name, forKey: Self.nameKey)
        } else {
            defaults.removeObject(forKey: Self.nameKey)
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
        defaults.removeObject(forKey: Self.nameKey)
        if let deletionError { throw deletionError }
    }
}

public enum LicenseKeyFormatting {
    public static func format(_ input: String) -> String {
        let compact = input.uppercased().filter { $0.isLetter || $0.isNumber }
        var body = compact
        while body.hasPrefix("EDITH") {
            body = String(body.dropFirst(5))
        }
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
