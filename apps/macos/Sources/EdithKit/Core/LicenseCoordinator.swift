import Foundation

public enum LicenseRiskState: Equatable {
    case noLicense
    case valid(LicenseEntitlement)
    case graceActive(remainingDays: Int, warn: Bool)
    case recovery
    case revoked
}

public struct LicenseCoordinator {
    public static let defaultGraceDays = 30
    public static let warnWindowDays = 5

    private let store: any LicenseCredentialStoring
    private let verifier: EntitlementVerifier
    private let graceDays: Int
    private let uptime: () -> TimeInterval
    private let bootSessionId: () -> String

    public init(
        store: any LicenseCredentialStoring,
        verifier: EntitlementVerifier = EntitlementVerifier(),
        graceDays: Int = LicenseCoordinator.defaultGraceDays,
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        bootSessionId: @escaping () -> String = TrustedTime.currentBootSessionId
    ) {
        self.store = store
        self.verifier = verifier
        self.graceDays = graceDays
        self.uptime = uptime
        self.bootSessionId = bootSessionId
    }

    public func riskState(deviceId: String, deviceKeyThumbprint: String, now: Date = Date())
        -> LicenseRiskState
    {
        guard let entitlement = ((try? store.read(.entitlement)) ?? nil), !entitlement.isEmpty
        else {
            return .noLicense
        }
        let trustedTime = TrustedTime.load(from: store)
        let effectiveNow = effectiveNow(now: now, trustedTime: trustedTime)
        switch verifier.validation(
            entitlement: entitlement, expectedDeviceId: deviceId,
            expectedThumbprint: deviceKeyThumbprint, now: effectiveNow)
        {
        case .valid(let payload):
            return trustedTime == nil
                ? .graceActive(remainingDays: graceDays, warn: false)
                : .valid(payload)
        case .expired(let payload):
            return graceState(expiresAt: payload.expiresAt, now: effectiveNow)
        case .notYetValid, .unknownKey:
            return .recovery
        case .invalid:
            return .revoked
        }
    }

    private func effectiveNow(now: Date, trustedTime: TrustedTime?) -> Date {
        guard let trustedTime else { return now }
        let anchoredElapsed =
            trustedTime.bootSessionId == bootSessionId()
            ? max(0, uptime() - trustedTime.monotonicAnchor)
            : 0
        let trustedNow = Date(
            timeIntervalSince1970: Double(trustedTime.lastServerTime) + anchoredElapsed)
        return max(now, trustedNow)
    }

    private func graceState(expiresAt: Int64, now: Date) -> LicenseRiskState {
        let elapsedDays = Int(floor((now.timeIntervalSince1970 - Double(expiresAt)) / 86_400))
        let remaining = graceDays - elapsedDays
        guard remaining > 0 else { return .recovery }
        return .graceActive(remainingDays: remaining, warn: remaining <= Self.warnWindowDays)
    }
}
