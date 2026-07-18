import Foundation

public enum ExtensionPermission: String, CaseIterable, Equatable, Sendable {
    case calendar
    case notifications
    case accessibility
    case inputMonitoring
    case fullDisk
    case screenRecording
    case camera
    case bluetooth
    case automation

    public var displayName: String {
        switch self {
        case .calendar: "Calendar"
        case .notifications: "Notifications"
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        case .fullDisk: "Full Disk Access"
        case .screenRecording: "Screen Recording"
        case .camera: "Camera"
        case .bluetooth: "Bluetooth"
        case .automation: "Automation"
        }
    }

    public var reason: String {
        switch self {
        case .calendar: "Shows your schedule in the Calendar extension."
        case .notifications: "Delivers usage limit, pacing, and reset alerts."
        case .accessibility: "Blocks keys during cleaning and pastes clipboard items in place."
        case .inputMonitoring: "Detects key presses while the keyboard is locked for cleaning."
        case .fullDisk: "Reads local service credentials and usage data when enabled."
        case .screenRecording: "Detects shared content and samples colors from the screen."
        case .camera: "Shows the camera preview in the Notch Shelf camera tab."
        case .bluetooth: "Shows device connection alerts around the notch."
        case .automation: "Controls Music playback and reads the current track."
        }
    }

    public var grantedDefaultsKey: String? {
        switch self {
        case .calendar: "permCalendarGranted"
        case .notifications: "permNotificationsGranted"
        case .accessibility: "permAccessibilityGranted"
        case .inputMonitoring: "permInputMonitoringGranted"
        case .fullDisk: "permFullDiskGranted"
        case .screenRecording: "permScreenRecordingGranted"
        case .camera: "permCameraGranted"
        case .bluetooth, .automation: nil
        }
    }
}

public enum ExtensionGroup: String, CaseIterable, Equatable, Sendable {
    case agent = "Agent"
    case system = "System"
    case media = "Media"
    case utilities = "Utilities"
}

public struct ExtensionRegistryEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let symbolName: String
    public let group: ExtensionGroup
    public let featured: Bool
    public let defaultsKey: String
    public let requiredPermissions: [ExtensionPermission]
    public let optionalPermissions: [ExtensionPermission]

    public init(
        id: String, title: String, subtitle: String, symbolName: String,
        group: ExtensionGroup, featured: Bool, defaultsKey: String,
        requiredPermissions: [ExtensionPermission] = [],
        optionalPermissions: [ExtensionPermission] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.group = group
        self.featured = featured
        self.defaultsKey = defaultsKey
        self.requiredPermissions = requiredPermissions
        self.optionalPermissions = optionalPermissions
    }
}

public enum ExtensionRegistry {
    public static let entries: [ExtensionRegistryEntry] = [
        ExtensionRegistryEntry(
            id: "usage", title: "Agent Usage",
            subtitle: "Claude and Codex limits, usage stats, and alerts.",
            symbolName: "chart.bar.fill", group: .agent, featured: true,
            defaultsKey: "tabUsageEnabled", requiredPermissions: [.notifications]),
        ExtensionRegistryEntry(
            id: "system", title: "System",
            subtitle: "Running apps, prevent sleep, and the keyboard-cleaning lock.",
            symbolName: "switch.2", group: .system, featured: true,
            defaultsKey: "tabSystemEnabled",
            requiredPermissions: [.accessibility, .inputMonitoring]),
        ExtensionRegistryEntry(
            id: "systemStats", title: "CPU & Memory in menu bar",
            subtitle: "Live CPU and memory readout as a menu bar item.",
            symbolName: "gauge.with.needle", group: .system, featured: false,
            defaultsKey: "menuBarSystemStats"),
        ExtensionRegistryEntry(
            id: "micMute", title: "Mic Mute",
            subtitle: "Mute every microphone system-wide with ⌘⇧M or the menu bar icon.",
            symbolName: "mic.slash.fill", group: .system, featured: false,
            defaultsKey: "micMuteEnabled"),
        ExtensionRegistryEntry(
            id: "music", title: "Music",
            subtitle: "Plays your local music folder, with media keys.",
            symbolName: "music.note", group: .media, featured: false,
            defaultsKey: "tabMusicEnabled", optionalPermissions: [.automation]),
        ExtensionRegistryEntry(
            id: "calendar", title: "Calendar",
            subtitle: "Shows your schedule in the panel and the app.",
            symbolName: "calendar", group: .media, featured: false,
            defaultsKey: "tabCalendarEnabled", requiredPermissions: [.calendar]),
        ExtensionRegistryEntry(
            id: "notchShelf", title: "Notch Shelf",
            subtitle: "File shelf, now playing, camera, and alerts around the notch.",
            symbolName: "tray.and.arrow.down", group: .media, featured: true,
            defaultsKey: "notchShelfEnabled", optionalPermissions: [.bluetooth, .camera]),
        ExtensionRegistryEntry(
            id: "clipboard", title: "Clipboard",
            subtitle: "Clipboard history with instant paste.",
            symbolName: "doc.on.clipboard", group: .utilities, featured: true,
            defaultsKey: "clipboardEnabled", optionalPermissions: [.accessibility]),
        ExtensionRegistryEntry(
            id: "focusDim", title: "Focus Dim",
            subtitle: "Dims everything behind your active app.",
            symbolName: "circle.lefthalf.filled", group: .utilities, featured: false,
            defaultsKey: "focusDimEnabled"),
        ExtensionRegistryEntry(
            id: "presenter", title: "Presenter",
            subtitle: "Blurs sensitive numbers while sharing your screen.",
            symbolName: "theatermasks.fill", group: .utilities, featured: false,
            defaultsKey: "presenterEnabled", requiredPermissions: [.screenRecording]),
        ExtensionRegistryEntry(
            id: "colorPicker", title: "Color Picker",
            subtitle: "System loupe on a hotkey, sampled color to your clipboard.",
            symbolName: "eyedropper", group: .utilities, featured: false,
            defaultsKey: "colorPickerEnabled", requiredPermissions: [.screenRecording]),
    ]
}
