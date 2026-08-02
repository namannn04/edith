import Foundation

public enum LidAwakeState {
    public static let enabledKey = "lidAwakeEnabled"
    public static let activeKey = "lidAwakeActive"
    public static let restoreOnQuitKey = "lidAwakeRestoreOnQuit"

    public static func isEnabled(_ defaults: UserDefaults = SharedDefaults.store) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    public static func isActive(_ defaults: UserDefaults = SharedDefaults.store) -> Bool {
        isEnabled(defaults) && defaults.bool(forKey: activeKey)
    }

    public static func setActive(_ active: Bool, _ defaults: UserDefaults = SharedDefaults.store) {
        defaults.set(active, forKey: activeKey)
    }

    public static func restoresOnQuit(_ defaults: UserDefaults = SharedDefaults.store) -> Bool {
        defaults.object(forKey: restoreOnQuitKey) as? Bool ?? true
    }
}

public enum LidAwakeOutcome: Equatable, Sendable {
    case applied
    case cancelled
    case failed(String)
}

public enum LidAwakeCommand {
    public static let toolPath = "/usr/bin/pmset"
    public static let authorizationToolPath = "/usr/bin/osascript"

    public static func arguments(active: Bool) -> [String] {
        ["-a", "disablesleep", active ? "1" : "0"]
    }

    public static func shellCommand(active: Bool) -> String {
        ([toolPath] + arguments(active: active)).joined(separator: " ")
    }

    public static func privilegedScript(active: Bool) -> String {
        "do shell script \"\(shellCommand(active: active))\" with administrator privileges"
    }

    public static func sleepDisabled(inPowerSettings output: String) -> Bool {
        for line in output.split(whereSeparator: { $0.isNewline }) {
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            guard fields.count >= 2, fields[0] == "SleepDisabled" else { continue }
            return fields[1] == "1"
        }
        return false
    }

    public static func outcome(status: Int32, errorOutput: String) -> LidAwakeOutcome {
        guard status != 0 else { return .applied }
        if errorOutput.contains("-128")
            || errorOutput.localizedCaseInsensitiveContains("User canceled")
        {
            return .cancelled
        }
        let lastLine = errorOutput.split(whereSeparator: { $0.isNewline }).last.map { String($0) }
        let message = (lastLine ?? "").trimmingCharacters(in: .whitespaces)
        return .failed(message.isEmpty ? "pmset exited with status \(status)" : message)
    }
}
