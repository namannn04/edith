import EdithKit
import Foundation
import Security

final class LidAwakeHelper: NSObject, NSXPCListenerDelegate, LidAwakePrivilegedProtocol {
    private let listener: NSXPCListener
    private let clientRequirement: SecRequirement?

    override init() {
        listener = NSXPCListener(machServiceName: LidAwakePrivilegedService.machServiceName)
        clientRequirement = Self.loadClientRequirement()
        super.init()
        listener.delegate = self
    }

    func run() {
        listener.resume()
        RunLoop.current.run()
    }

    func listener(
        _ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        guard let clientRequirement, Self.isTrusted(connection, requirement: clientRequirement)
        else { return false }
        connection.exportedInterface = NSXPCInterface(with: LidAwakePrivilegedProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func setSleepDisabled(_ disable: Bool, reply: @escaping (NSError?) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: LidAwakeCommand.toolPath)
        process.arguments = LidAwakeCommand.arguments(active: disable)

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            reply(error as NSError)
            return
        }

        process.waitUntilExit()
        guard process.terminationStatus != 0 else {
            reply(nil)
            return
        }

        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8) ?? "pmset failed"
        reply(
            NSError(
                domain: LidAwakePrivilegedService.bundleIdentifier,
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message]))
    }

    private static func loadClientRequirement() -> SecRequirement? {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let app =
            executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        var code: SecStaticCode?
        guard
            SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess,
            let code
        else { return nil }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(code, [], &requirement) == errSecSuccess else {
            return nil
        }
        return requirement
    }

    private static func isTrusted(
        _ connection: NSXPCConnection, requirement: SecRequirement
    ) -> Bool {
        let attributes = [kSecGuestAttributePid: NSNumber(value: connection.processIdentifier)]
        var code: SecCode?
        guard
            SecCodeCopyGuestWithAttributes(nil, attributes as CFDictionary, [], &code)
                == errSecSuccess,
            let code
        else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}

LidAwakeHelper().run()
