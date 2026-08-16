import EdithKit
import Foundation

final class LidAwakeHelper: NSObject, NSXPCListenerDelegate, LidAwakePrivilegedProtocol {
    private let listener: NSXPCListener

    override init() {
        listener = NSXPCListener(machServiceName: LidAwakePrivilegedService.machServiceName)
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
}

LidAwakeHelper().run()
