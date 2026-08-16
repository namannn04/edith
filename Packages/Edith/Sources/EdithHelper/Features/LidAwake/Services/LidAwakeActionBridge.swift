import EdithKit
import Foundation

@MainActor
final class LidAwakeActionBridge {
    static let shared = LidAwakeActionBridge()

    private var token: NSObjectProtocol?

    func install(services: AppServices) {
        guard token == nil else { return }
        token = IPC.observe(
            IPC.Name.requestLidAwakeAction,
            info: { [weak self] info in
                MainActor.assumeIsolated {
                    self?.receive(info, services: services)
                }
            })
    }

    private func receive(_ info: [AnyHashable: Any], services: AppServices) {
        guard let rawAction = info[LidAwakeIPC.actionKey] as? String,
            let action = LidAwakeIPC.Action(rawValue: rawAction)
        else {
            IPC.post(
                IPC.Name.lidAwakeActionResult,
                userInfo: [
                    LidAwakeIPC.okKey: false,
                    LidAwakeIPC.errorKey: "The Lid Awake action is invalid.",
                ])
            return
        }
        if action == .on, services.lidAwake == nil {
            SharedDefaults.store.set(true, forKey: LidAwakeState.enabledKey)
            services.sync()
        }
        guard let engine = services.lidAwake else {
            var payload = inactivePayload()
            payload[LidAwakeIPC.okKey] = action != .on
            if action == .on {
                payload[LidAwakeIPC.errorKey] = "The Lid Awake extension could not start."
            }
            IPC.post(IPC.Name.lidAwakeActionResult, userInfo: payload)
            return
        }
        switch action {
        case .status:
            var payload = engine.statusPayload()
            payload[LidAwakeIPC.okKey] = true
            IPC.post(IPC.Name.lidAwakeActionResult, userInfo: payload)
        case .on:
            guard let rawSession = info[LidAwakeIPC.sessionKey] as? String,
                let session = LidAwakeSession(rawValue: rawSession)
            else {
                var payload = engine.statusPayload()
                payload[LidAwakeIPC.okKey] = false
                payload[LidAwakeIPC.errorKey] = "The Lid Awake session is invalid."
                IPC.post(IPC.Name.lidAwakeActionResult, userInfo: payload)
                return
            }
            engine.start(session: session) { outcome in
                IPC.post(
                    IPC.Name.lidAwakeActionResult,
                    userInfo: engine.resultPayload(outcome))
            }
        case .off:
            engine.stop { outcome in
                IPC.post(
                    IPC.Name.lidAwakeActionResult,
                    userInfo: engine.resultPayload(outcome))
            }
        }
    }

    private func inactivePayload() -> [String: Any] {
        [
            "extensionEnabled": false,
            "active": false,
            "requestedActive": false,
            "applying": false,
            "batterySuspended": false,
            "session": LidAwakeState.session().rawValue,
            "batteryThreshold": SharedDefaults.store.integer(
                forKey: LidAwakeState.batteryThresholdKey),
            "restoreOnQuit": LidAwakeState.restoresOnQuit(),
            "helperStatus": "notRegistered",
            "appRunning": true,
        ]
    }
}
