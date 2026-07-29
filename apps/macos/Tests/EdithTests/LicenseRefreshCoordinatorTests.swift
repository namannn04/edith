import Foundation
import Testing

@testable import EdithKit

@Suite struct LicenseRefreshCoordinatorTests {
    private let baseURL = URL(string: "https://example.test/api")!
    private let now = Date(timeIntervalSince1970: 1_752_000_000)

    @Test func freshTokenSkipsRotation() async throws {
        let transport = RefreshCountingTransport()
        let store = try makeStore(accessTokenExpiry: "2099-01-01T00:00:00.000Z")
        let coordinator = LicenseRefreshCoordinator()

        let outcome = try await coordinator.refreshIfStale(
            credentialStore: store, now: now
        ) {
            self.makeSession(transport: transport, store: store)
        }

        #expect(outcome == .alreadyFresh)
        #expect(transport.refreshCount == 0)
    }

    @Test func staleTokenRotatesOnce() async throws {
        let transport = RefreshCountingTransport()
        let store = try makeStore(accessTokenExpiry: iso(offset: -600))
        let coordinator = LicenseRefreshCoordinator()

        let outcome = try await coordinator.refreshIfStale(
            credentialStore: store, now: now
        ) {
            self.makeSession(transport: transport, store: store)
        }

        #expect(outcome == .rotated)
        #expect(transport.refreshCount == 1)
        #expect(try store.read(.refreshCredential) == "edithrc_rotated1")
    }

    @Test func concurrentStaleRefreshesRotateOnlyOnce() async throws {
        let transport = RefreshCountingTransport(refreshDelay: .milliseconds(50))
        let store = try makeStore(accessTokenExpiry: iso(offset: -600))
        let coordinator = LicenseRefreshCoordinator()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    _ = try? await coordinator.refreshIfStale(
                        credentialStore: store, now: self.now
                    ) {
                        self.makeSession(transport: transport, store: store)
                    }
                }
            }
        }

        #expect(transport.refreshCount == 1)
        #expect(try store.read(.refreshCredential) == "edithrc_rotated1")
    }

    @Test func unconditionalRefreshJoinsInFlightRotation() async throws {
        let transport = RefreshCountingTransport(refreshDelay: .milliseconds(50))
        let store = try makeStore(accessTokenExpiry: iso(offset: -600))
        let coordinator = LicenseRefreshCoordinator()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<8 {
                group.addTask {
                    if index.isMultiple(of: 2) {
                        _ = try? await coordinator.refresh {
                            self.makeSession(transport: transport, store: store)
                        }
                    } else {
                        _ = try? await coordinator.refreshIfStale(
                            credentialStore: store, now: self.now
                        ) {
                            self.makeSession(transport: transport, store: store)
                        }
                    }
                }
            }
        }

        #expect(transport.refreshCount == 1)
        #expect(try store.read(.refreshCredential) == "edithrc_rotated1")
    }

    @Test func rotationIsAllowedAgainAfterTheInFlightOneFinishes() async throws {
        let transport = RefreshCountingTransport()
        let store = try makeStore(accessTokenExpiry: iso(offset: -600))
        let coordinator = LicenseRefreshCoordinator()

        _ = try await coordinator.refresh {
            self.makeSession(transport: transport, store: store)
        }
        _ = try await coordinator.refresh {
            self.makeSession(transport: transport, store: store)
        }

        #expect(transport.refreshCount == 2)
        #expect(try store.read(.refreshCredential) == "edithrc_rotated2")
    }

    @Test func rejectedRefreshPropagatesToEveryJoinedCaller() async throws {
        let transport = RefreshCountingTransport(
            refreshDelay: .milliseconds(50), refreshStatusCode: 403)
        let store = try makeStore(accessTokenExpiry: iso(offset: -600))
        let coordinator = LicenseRefreshCoordinator()

        let failures = await withTaskGroup(of: Bool.self) { group -> Int in
            for _ in 0..<4 {
                group.addTask {
                    do {
                        _ = try await coordinator.refreshIfStale(
                            credentialStore: store, now: self.now
                        ) {
                            self.makeSession(transport: transport, store: store)
                        }
                        return false
                    } catch {
                        return true
                    }
                }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }

        #expect(failures == 4)
        #expect(transport.refreshAttemptCount == 1)
        #expect(transport.refreshCount == 0)
        #expect(try store.read(.refreshCredential) == "edithrc_seed")
    }

    private func iso(offset: TimeInterval) -> String {
        ISO8601DateFormatter().string(from: now.addingTimeInterval(offset))
    }

    private func makeStore(accessTokenExpiry: String) throws -> InMemoryLicenseCredentialStore {
        let store = InMemoryLicenseCredentialStore()
        try store.write("signed-entitlement", item: .entitlement)
        try store.write("edithrc_seed", item: .refreshCredential)
        try StoredAccessToken(token: "token.sig", expiresAt: accessTokenExpiry).save(to: store)
        try TrustedTime.record(serverTime: now).save(to: store)
        _ = try DeviceIdentity(
            credentialStore: store,
            keyStore: DeviceKeyStore(store: store, secureEnclaveAvailable: false))
        return store
    }

    private func makeSession(
        transport: RefreshCountingTransport, store: InMemoryLicenseCredentialStore
    ) -> LicenseSession {
        LicenseSession(
            client: LicenseClient(transport: transport, baseURL: baseURL),
            credentialStore: store,
            deviceKeyStore: DeviceKeyStore(store: store, secureEnclaveAvailable: false),
            machineIdentifier: { "hardware-1" },
            appVersion: "9.9.9")
    }
}

private final class RefreshCountingTransport: LicenseTransport, @unchecked Sendable {
    private let lock = NSLock()
    private let refreshDelay: Duration
    private let refreshStatusCode: Int
    private var rotations = 0
    private var attempts = 0

    var refreshCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return rotations
    }

    var refreshAttemptCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return attempts
    }

    init(refreshDelay: Duration = .zero, refreshStatusCode: Int = 200) {
        self.refreshDelay = refreshDelay
        self.refreshStatusCode = refreshStatusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path ?? ""
        if path.hasSuffix("/challenge") {
            return respond(
                statusCode: 200,
                body: #"{"challengeId":"ch-1","nonce":"n-1","expiresAt":"2099-01-01T00:00:00Z"}"#,
                url: request.url!)
        }
        lock.lock()
        attempts += 1
        lock.unlock()
        if refreshDelay != .zero {
            try await Task.sleep(for: refreshDelay)
        }
        guard refreshStatusCode == 200 else {
            return respond(
                statusCode: refreshStatusCode, body: #"{"error":"invalid_credentials"}"#,
                url: request.url!)
        }
        lock.lock()
        rotations += 1
        let generation = rotations
        lock.unlock()
        return respond(
            statusCode: 200,
            body: """
                {"ok":true,"entitlement":"signed-entitlement-\(generation)",
                "refreshCredential":"edithrc_rotated\(generation)",
                "accessToken":"token\(generation).sig",
                "accessTokenExpiresAt":"2099-01-01T00:00:00.000Z"}
                """,
            url: request.url!)
    }

    private func respond(statusCode: Int, body: String, url: URL) -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}
