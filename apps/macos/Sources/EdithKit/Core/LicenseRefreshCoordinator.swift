import Foundation

public enum LicenseRefreshOutcome: Equatable, Sendable {
    case alreadyFresh
    case joinedInFlight
    case rotated
}

public func licenseRefreshIsStale(
    credentialStore: any LicenseCredentialStoring, now: Date = Date()
) -> Bool {
    licenseUpdaterTokenIsStale(
        accessToken: StoredAccessToken.load(from: credentialStore),
        hasRefreshCredential: ((try? credentialStore.read(.refreshCredential)) ?? nil) != nil,
        now: now)
}

public actor LicenseRefreshCoordinator {
    public static let shared = LicenseRefreshCoordinator()

    private var inFlight: Task<Void, Error>?

    public init() {}

    @discardableResult
    public func refreshIfStale(
        credentialStore: any LicenseCredentialStoring,
        now: Date = Date(),
        makeSession: @escaping () -> LicenseSession
    ) async throws -> LicenseRefreshOutcome {
        if let inFlight {
            try await inFlight.value
            return .joinedInFlight
        }
        guard licenseRefreshIsStale(credentialStore: credentialStore, now: now) else {
            return .alreadyFresh
        }
        try await rotate(makeSession)
        return .rotated
    }

    @discardableResult
    public func refresh(
        makeSession: @escaping () -> LicenseSession
    ) async throws -> LicenseRefreshOutcome {
        if let inFlight {
            try await inFlight.value
            return .joinedInFlight
        }
        try await rotate(makeSession)
        return .rotated
    }

    private func rotate(_ makeSession: @escaping () -> LicenseSession) async throws {
        let task = Task { try await makeSession().refresh() }
        inFlight = task
        defer { inFlight = nil }
        try await task.value
    }
}
