import EdithKit
import Foundation
import Security
import ServiceManagement

enum LidAwakePrivilegedClientState: String, Equatable {
    case notRegistered
    case awaitingApproval
    case enabled
    case notFound
}

enum LidAwakePrivilegedClientError: LocalizedError {
    case helperUnavailable(LidAwakePrivilegedClientState)
    case connectionFailed(String)
    case remoteError(Error)

    var errorDescription: String? {
        switch self {
        case .helperUnavailable(let state):
            switch state {
            case .awaitingApproval:
                return
                    "Approve Edith in System Settings > General > Login Items, then run the command again."
            case .notFound:
                return "Edith's privileged helper is missing. Reinstall Edith and try again."
            case .notRegistered:
                return
                    "Edith's privileged helper could not be registered. Reopen Edith and try again."
            case .enabled:
                return "Edith's privileged helper is unavailable."
            }
        case .connectionFailed(let detail):
            return "Could not connect to Edith's privileged helper: \(detail)"
        case .remoteError(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
final class LidAwakePrivilegedClient {
    private static let fingerprintKey = "lidAwakePrivilegedHelperFingerprint"

    private let service = SMAppService.daemon(
        plistName: LidAwakePrivilegedService.plistName)
    private let fingerprint = LidAwakePrivilegedClient.helperFingerprint()
    private var connection: NSXPCConnection?
    private var approvalRequired = false
    private var registrationInFlight = false
    private(set) var registrationError: String?

    var state: LidAwakePrivilegedClientState {
        let serviceState: LidAwakePrivilegedClientState = switch service.status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .awaitingApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
        return approvalRequired && serviceState != .enabled ? .awaitingApproval : serviceState
    }

    var isUsable: Bool { state == .enabled }

    func register() {
        guard !registrationInFlight else { return }
        let currentState = state
        if currentState == .awaitingApproval {
            persistFingerprint()
            return
        }
        if currentState == .enabled {
            guard let fingerprint else { return }
            if UserDefaults.standard.string(forKey: Self.fingerprintKey) == fingerprint { return }
            reregister()
            return
        }
        registerCurrent()
    }

    private func registerCurrent() {
        do {
            try service.register()
            approvalRequired = false
            registrationError = nil
            persistFingerprint()
        } catch {
            let failure = error as NSError
            if service.status == .requiresApproval
                || (failure.domain == "SMAppServiceErrorDomain" && failure.code == 1)
            {
                approvalRequired = true
                registrationError = nil
                persistFingerprint()
            } else {
                registrationError =
                    "Service Management registration failed (\(failure.domain) \(failure.code)): \(failure.localizedDescription)"
                NSLog("%@", registrationError ?? "Service Management registration failed")
            }
        }
    }

    private func reregister() {
        registrationInFlight = true
        service.unregister { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.registrationInFlight = false
                if let error {
                    let failure = error as NSError
                    self.registrationError =
                        "Service Management update failed (\(failure.domain) \(failure.code)): \(failure.localizedDescription)"
                    return
                }
                self.registerCurrent()
            }
        }
    }

    private func persistFingerprint() {
        if let fingerprint {
            UserDefaults.standard.set(fingerprint, forKey: Self.fingerprintKey)
        }
    }

    func unregister() {
        do {
            try service.unregister()
        } catch {
            NSLog("SMAppService unregistration failed: \((error as NSError).localizedDescription)")
        }
    }

    func setSleepDisabled(_ disable: Bool) async throws {
        var currentState = state
        if currentState == .awaitingApproval {
            registerCurrent()
            currentState = state
        }
        guard currentState == .enabled else {
            if currentState == .awaitingApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
            throw LidAwakePrivilegedClientError.helperUnavailable(currentState)
        }
        let connection = connection ?? makeConnection()
        self.connection = connection
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            let reply = LidAwakePrivilegedReply(continuation)
            guard
                let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                    reply.resume(
                        throwing: LidAwakePrivilegedClientError.connectionFailed(
                            error.localizedDescription))
                }) as? LidAwakePrivilegedProtocol
            else {
                reply.resume(
                    throwing: LidAwakePrivilegedClientError.connectionFailed(
                        "The helper proxy is unavailable."))
                return
            }
            proxy.setSleepDisabled(disable) { error in
                if let error {
                    reply.resume(throwing: LidAwakePrivilegedClientError.remoteError(error))
                } else {
                    reply.resume()
                }
            }
        }
    }

    private func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(
            machServiceName: LidAwakePrivilegedService.machServiceName,
            options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(
            with: LidAwakePrivilegedProtocol.self)
        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        connection.interruptionHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        connection.resume()
        return connection
    }

    private static func helperFingerprint() -> String? {
        let helper = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/PrivilegedHelperTools")
            .appendingPathComponent(LidAwakePrivilegedService.bundleIdentifier)
        var code: SecStaticCode?
        guard
            SecStaticCodeCreateWithPath(helper as CFURL, [], &code) == errSecSuccess,
            let code
        else { return nil }
        var information: CFDictionary?
        guard
            SecCodeCopySigningInformation(code, [], &information) == errSecSuccess,
            let values = information as? [CFString: Any],
            let data = values[kSecCodeInfoUnique] as? Data
        else { return nil }
        return data.map { String(format: "%02x", $0) }.joined()
    }
}

private final class LidAwakePrivilegedReply: @unchecked Sendable {
    private let lock = NSLock()
    private let continuation: CheckedContinuation<Void, Error>
    private var finished = false

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume() {
        finish(.success(()))
    }

    func resume(throwing error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        lock.unlock()
        continuation.resume(with: result)
    }
}
