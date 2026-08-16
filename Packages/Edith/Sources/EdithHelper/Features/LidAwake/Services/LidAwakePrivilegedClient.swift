import EdithKit
import Foundation
import ServiceManagement

enum LidAwakePrivilegedClientState: Equatable {
    case notRegistered
    case awaitingApproval
    case enabled
    case notFound
}

enum LidAwakePrivilegedClientError: LocalizedError {
    case helperUnavailable
    case connectionFailed(String)
    case remoteError(Error)

    var errorDescription: String? {
        switch self {
        case .helperUnavailable:
            return "Edith's privileged helper is not approved yet."
        case .connectionFailed(let detail):
            return "Could not connect to Edith's privileged helper: \(detail)"
        case .remoteError(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
final class LidAwakePrivilegedClient {
    private let service = SMAppService.daemon(
        plistName: LidAwakePrivilegedService.plistName)
    private var connection: NSXPCConnection?

    var state: LidAwakePrivilegedClientState {
        switch service.status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .awaitingApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    var isUsable: Bool { state == .enabled }

    func register() {
        do {
            try service.register()
        } catch {
            NSLog("SMAppService registration failed: \((error as NSError).localizedDescription)")
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
        let proxy = try ensureProxy()
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            proxy.setSleepDisabled(disable) { error in
                if let error {
                    continuation.resume(
                        throwing: LidAwakePrivilegedClientError.remoteError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func ensureProxy() throws -> LidAwakePrivilegedProtocol {
        guard isUsable else {
            throw LidAwakePrivilegedClientError.helperUnavailable
        }

        let connection = connection ?? makeConnection()
        self.connection = connection
        var connectionError: Error?
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            connectionError = error
        } as? LidAwakePrivilegedProtocol

        if let connectionError {
            connection.invalidate()
            self.connection = nil
            throw LidAwakePrivilegedClientError.connectionFailed(
                connectionError.localizedDescription)
        }
        guard let proxy else {
            throw LidAwakePrivilegedClientError.connectionFailed(
                "The helper proxy is unavailable.")
        }
        return proxy
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
}
