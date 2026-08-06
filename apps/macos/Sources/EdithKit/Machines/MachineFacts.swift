import Foundation

public struct MachineSessionSummary: Equatable, Sendable {
    public var who: [String]
    public var updatesAvailable: Int?
    public var macAddress: String?

    public init(who: [String] = [], updatesAvailable: Int? = nil, macAddress: String? = nil) {
        self.who = who
        self.updatesAvailable = updatesAvailable
        self.macAddress = macAddress
    }
}

public enum MachineFacts {
    public static let whoCommand = "who 2>/dev/null | head -20"

    public static let macAddressCommand =
        "cat /sys/class/net/*/address 2>/dev/null | grep -v '00:00:00:00:00:00' | head -1"

    public static let updatesCommand = """
        if command -v apt-get >/dev/null 2>&1; then \
        apt-get -s -o Debug::NoLocking=1 upgrade 2>/dev/null | grep -c '^Inst'; \
        elif command -v dnf >/dev/null 2>&1; then dnf -q check-update 2>/dev/null | grep -c '^[a-zA-Z]'; \
        elif command -v pacman >/dev/null 2>&1; then pacman -Qu 2>/dev/null | wc -l; \
        else echo -1; fi
        """

    public static func parseWho(_ output: String) -> [String] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3 else { return nil }
            let user = String(parts[0])
            let tty = String(parts[1])
            let rest = parts.dropFirst(2).joined(separator: " ")
            return "\(user) on \(tty) since \(rest)"
        }
    }

    public static func parseUpdates(_ output: String) -> Int? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    public static func parseMACAddress(_ output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$"
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return trimmed.lowercased()
    }
}

public enum ServiceCommands {
    public static func list() -> String {
        "systemctl list-units --type=service --all --no-pager --no-legend --plain 2>/dev/null"
            + " | head -200"
    }

    public static func action(_ action: String, unit: String) -> String {
        "systemctl \(action) \(ShellQuote.quote(unit)) 2>&1 || "
            + "sudo -n systemctl \(action) \(ShellQuote.quote(unit)) 2>&1"
    }

    public static func journal(unit: String, lines: Int, follow: Bool) -> String {
        var command = "journalctl -u \(ShellQuote.quote(unit)) -n \(lines) --no-pager"
        if follow { command += " -f" }
        return command + " 2>&1"
    }

    public static func reboot() -> String {
        "sudo -n systemctl reboot 2>&1 || systemctl reboot 2>&1"
    }

    public static func shutdown() -> String {
        "sudo -n systemctl poweroff 2>&1 || systemctl poweroff 2>&1"
    }
}

public struct SystemdService: Identifiable, Equatable, Sendable {
    public var unit: String
    public var load: String
    public var active: String
    public var sub: String
    public var describes: String

    public var id: String { unit }

    public init(unit: String, load: String, active: String, sub: String, describes: String) {
        self.unit = unit
        self.load = load
        self.active = active
        self.sub = sub
        self.describes = describes
    }

    public var isRunning: Bool { sub == "running" }
    public var isFailed: Bool { active == "failed" || sub == "failed" }

    public var displayName: String {
        unit.hasSuffix(".service") ? String(unit.dropLast(8)) : unit
    }
}

extension ServiceCommands {
    public static func parse(_ output: String) -> [SystemdService] {
        output.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("●") else { return nil }
            let parts = trimmed.split(
                separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard parts.count >= 4, parts[0].hasSuffix(".service") else { return nil }
            return SystemdService(
                unit: String(parts[0]), load: String(parts[1]), active: String(parts[2]),
                sub: String(parts[3]),
                describes: parts.count > 4 ? String(parts[4]) : "")
        }
    }
}

public enum WakeOnLAN {
    public static func magicPacket(macAddress: String) -> Data? {
        let hex = macAddress.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        guard hex.count == 6 else { return nil }
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: hex) }
        return packet
    }
}
