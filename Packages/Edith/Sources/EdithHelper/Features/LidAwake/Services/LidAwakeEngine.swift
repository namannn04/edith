import AppKit
import EdithKit

@MainActor
final class LidAwakeEngine: ObservableObject, FeatureModule {
    @Published private(set) var active = false
    @Published private(set) var applying = false
    @Published private(set) var lastError: String?
    @Published private(set) var session = LidAwakeSession.indefinite
    @Published private(set) var remaining: TimeInterval?
    @Published private(set) var batterySuspended = false

    private let privilegedClient = LidAwakePrivilegedClient()
    private let batteryMonitor = LidAwakeBatteryMonitor()
    private let lidMonitor = LidAwakeLidMonitor()
    private let displayWakeKeeper = LidAwakeDisplayWakeKeeper()
    private let autoOffTimer = LidAwakeAutoOffTimer()
    private var lidSession = LidAwakeLidSessionTracker()
    private var intent = false
    private var batteryOverride = false
    private var lastBattery: LidAwakeBatterySnapshot?
    private var terminateObserver: NSObjectProtocol?
    private var stopped = false

    init() {
        session = LidAwakeState.session()
        let savedDeadline = LidAwakeState.sessionDeadline()
        privilegedClient.register()
        active = Self.readSystemState()
        intent = active
        if active {
            displayWakeKeeper.prevent()
            configureSession(session, deadline: savedDeadline)
        }
        batteryMonitor.onChange = { [weak self] snapshot in
            Task { @MainActor in self?.handleBattery(snapshot) }
        }
        lidMonitor.onChange = { [weak self] closed in
            Task { @MainActor in self?.handleLid(closed) }
        }
        autoOffTimer.onExpire = { [weak self] in
            Task { @MainActor in self?.stop() }
        }
        autoOffTimer.onTick = { [weak self] in
            Task { @MainActor in self?.updateRemaining() }
        }
        batteryMonitor.start()
        lidMonitor.start()
        publishState()
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.shutdown()
            }
        }
    }

    func shutdown() {
        stopEngine(force: false)
    }

    func uninstall() {
        stopEngine(force: true)
    }

    func toggle() {
        if intent { stop() } else { start(session: session) }
    }

    func setActive(_ wanted: Bool) {
        if wanted { start(session: session) } else { stop() }
    }

    func start(session: LidAwakeSession) {
        guard !applying, !stopped else { return }
        let shouldOverride = lastBattery.map {
            !$0.onAC && $0.percent < batteryThreshold
        } ?? false
        if active, !batterySuspended {
            configureSession(session, deadline: nil)
            publishState()
            return
        }
        applySystemState(
            true,
            intentAfter: true,
            suspendedAfter: false,
            overrideAfter: shouldOverride,
            sessionAfter: session,
            configureSessionAfter: true)
    }

    func stop() {
        guard !applying, active || intent else { return }
        applySystemState(
            false,
            intentAfter: false,
            suspendedAfter: false,
            overrideAfter: false,
            sessionAfter: session,
            configureSessionAfter: false)
    }

    func refreshFromSystem() {
        guard !applying, !stopped else { return }
        let system = Self.readSystemState()
        if batterySuspended {
            active = false
        } else if system != active {
            active = system
            intent = system
            if !system {
                displayWakeKeeper.allow()
                autoOffTimer.cancel()
                lidSession.cancel()
            }
            publishState()
        }
        updateRemaining()
    }

    func syncSettings() {
        guard !stopped else { return }
        if let lastBattery { handleBattery(lastBattery) }
        updateRemaining()
    }

    private var batteryThreshold: Int {
        SharedDefaults.store.integer(forKey: LidAwakeState.batteryThresholdKey)
    }

    private func handleBattery(_ snapshot: LidAwakeBatterySnapshot) {
        lastBattery = snapshot
        batteryOverride = LidAwakeBatteryPolicy.shouldKeepOverride(
            batteryOverride, onAC: snapshot.onAC)
        guard intent, !applying else { return }
        let action = LidAwakeBatteryPolicy.decide(
            intent: intent,
            suspended: batterySuspended,
            overridden: batteryOverride,
            percent: snapshot.percent,
            onAC: snapshot.onAC,
            threshold: batteryThreshold)
        switch action {
        case .suspend:
            applySystemState(
                false,
                intentAfter: true,
                suspendedAfter: true,
                overrideAfter: false,
                sessionAfter: session,
                configureSessionAfter: false)
        case .resume:
            applySystemState(
                true,
                intentAfter: true,
                suspendedAfter: false,
                overrideAfter: false,
                sessionAfter: session,
                configureSessionAfter: false)
        case .none:
            break
        }
    }

    private func handleLid(_ closed: Bool) {
        guard intent, session == .untilLidReopens, lidSession.isActive else { return }
        if lidSession.handle(lidClosed: closed) { stop() }
    }

    private func applySystemState(
        _ systemActive: Bool,
        intentAfter: Bool,
        suspendedAfter: Bool,
        overrideAfter: Bool,
        sessionAfter: LidAwakeSession,
        configureSessionAfter: Bool
    ) {
        guard !applying else { return }
        applying = true
        lastError = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.apply(systemActive: systemActive)
            self.finish(
                outcome,
                systemActive: systemActive,
                intentAfter: intentAfter,
                suspendedAfter: suspendedAfter,
                overrideAfter: overrideAfter,
                sessionAfter: sessionAfter,
                configureSessionAfter: configureSessionAfter)
        }
    }

    private func apply(systemActive: Bool) async -> LidAwakeOutcome {
        if privilegedClient.isUsable {
            do {
                try await privilegedClient.setSleepDisabled(systemActive)
                return .applied
            } catch {
                let fallback = await Task.detached(priority: .userInitiated) {
                    Self.applyViaOsascript(active: systemActive)
                }.value
                if case .failed = fallback { return .failed(error.localizedDescription) }
                return fallback
            }
        }
        return await Task.detached(priority: .userInitiated) {
            Self.applyViaOsascript(active: systemActive)
        }.value
    }

    private func finish(
        _ outcome: LidAwakeOutcome,
        systemActive: Bool,
        intentAfter: Bool,
        suspendedAfter: Bool,
        overrideAfter: Bool,
        sessionAfter: LidAwakeSession,
        configureSessionAfter: Bool
    ) {
        applying = false
        switch outcome {
        case .applied:
            active = systemActive
            intent = intentAfter
            batterySuspended = suspendedAfter
            batteryOverride = overrideAfter
            session = sessionAfter
            if systemActive { displayWakeKeeper.prevent() } else { displayWakeKeeper.allow() }
            if !intentAfter {
                autoOffTimer.cancel()
                lidSession.cancel()
                remaining = nil
                LidAwakeState.setSessionDeadline(nil)
            } else if configureSessionAfter {
                configureSession(sessionAfter, deadline: nil)
            } else {
                updateRemaining()
            }
            lastError = nil
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            publishState()
        case .cancelled:
            lastError = nil
        case .failed(let message):
            lastError = message
        }
    }

    private func configureSession(_ session: LidAwakeSession, deadline: Date?) {
        self.session = session
        LidAwakeState.setSession(session)
        autoOffTimer.cancel()
        lidSession.cancel()
        switch session {
        case .indefinite:
            LidAwakeState.setSessionDeadline(nil)
        case .fifteenMinutes, .thirtyMinutes, .oneHour, .twoHours:
            let minutes = session.minutes ?? 0
            let target = deadline.flatMap { $0 > Date() ? $0 : nil }
                ?? Date().addingTimeInterval(TimeInterval(minutes) * 60)
            autoOffTimer.start(deadline: target)
            LidAwakeState.setSessionDeadline(target)
        case .untilLidReopens:
            LidAwakeState.setSessionDeadline(nil)
            lidSession.start(lidClosed: lidMonitor.isClosed)
        }
        updateRemaining()
    }

    private func updateRemaining() {
        remaining = autoOffTimer.remaining
        if let deadline = autoOffTimer.deadline {
            LidAwakeState.setSessionDeadline(deadline)
        }
    }

    private func stopEngine(force: Bool) {
        guard !stopped else { return }
        stopped = true
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
            self.terminateObserver = nil
        }
        batteryMonitor.stop()
        lidMonitor.stop()
        displayWakeKeeper.allow()
        autoOffTimer.cancel()
        lidSession.cancel()
        let shouldRestore = active || batterySuspended || intent
        if shouldRestore && (force || LidAwakeState.restoresOnQuit()) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let outcome = await self.apply(systemActive: false)
                if case .applied = outcome {
                    self.active = false
                    self.intent = false
                    self.batterySuspended = false
                    LidAwakeState.setActive(false)
                    IPC.post(IPC.Name.lidAwakeChanged)
                }
            }
        } else {
            active = false
            intent = false
            batterySuspended = false
            LidAwakeState.setActive(false)
            IPC.post(IPC.Name.lidAwakeChanged)
        }
    }

    private func publishState() {
        LidAwakeState.setActive(active)
        LidAwakeState.setSession(session)
        IPC.post(IPC.Name.lidAwakeChanged)
    }

    private nonisolated static func applyViaOsascript(active: Bool) -> LidAwakeOutcome {
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
