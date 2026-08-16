import AppKit
import EdithKit

@MainActor
final class LidAwakeEngine: ObservableObject, FeatureModule {
    @Published private(set) var active = false
    @Published private(set) var applying = false
    @Published private(set) var lastError: String?

    private var terminateObserver: NSObjectProtocol?

    init() {
        active = Self.readSystemState()
        publishState()
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.shutdown()
            }
        }
    }

    func shutdown() {
        restoreSleep(force: false)
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
            self.terminateObserver = nil
        }
    }

    func uninstall() {
        restoreSleep(force: true)
        shutdown()
    }

    private func restoreSleep(force: Bool) {
        guard active, force || LidAwakeState.restoresOnQuit() else { return }
        if case .applied = Self.apply(active: false) {
            active = false
        }
        publishState()
    }

    func toggle() {
        setActive(!active)
    }

    func setActive(_ wanted: Bool) {
        guard !applying, wanted != active else { return }
        applying = true
        lastError = nil
        Task.detached(priority: .userInitiated) {
            let outcome = Self.apply(active: wanted)
            await MainActor.run { self.finish(wanted, outcome) }
        }
    }

    func refreshFromSystem() {
        guard !applying else { return }
        let system = Self.readSystemState()
        guard system != active else { return }
        active = system
        publishState()
    }

    private func finish(_ wanted: Bool, _ outcome: LidAwakeOutcome) {
        applying = false
        switch outcome {
        case .applied:
            active = wanted
            lastError = nil
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        case .cancelled:
            lastError = nil
        case .failed(let message):
            lastError = message
        }
        publishState()
    }

    private func publishState() {
        LidAwakeState.setActive(active)
        IPC.post(IPC.Name.lidAwakeChanged)
    }

    private nonisolated static func apply(active: Bool) -> LidAwakeOutcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: LidAwakeCommand.authorizationToolPath)
        process.arguments = ["-e", LidAwakeCommand.privilegedScript(active: active)]
        let errors = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        do {
            try process.run()
        } catch {
            return .failed(error.localizedDescription)
        }
        let data = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return LidAwakeCommand.outcome(
            status: process.terminationStatus,
            errorOutput: String(data: data, encoding: .utf8) ?? "")
    }

    private nonisolated static func readSystemState() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: LidAwakeCommand.toolPath)
        process.arguments = ["-g"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return false
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return LidAwakeCommand.sleepDisabled(
            inPowerSettings: String(data: data, encoding: .utf8) ?? "")
    }
}
