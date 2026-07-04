import AppKit
import Carbon.HIToolbox
import SwiftUI

// The app theme: one accent used by the limit rings, the activity calendar,
// and the player controls. Stored by name in UserDefaults ("theme").
// "accent" (default) follows the macOS system accent color.
let themePalette: [(name: String, color: Color)] = [
    ("blue", .blue), ("indigo", .indigo), ("teal", .teal), ("green", .green),
    ("purple", .purple), ("pink", .pink), ("red", .red), ("orange", .orange),
]

func themeColor(_ name: String) -> Color {
    if name == "accent" { return .accentColor }
    return themePalette.first { $0.name == name }?.color ?? .accentColor
}

struct SettingsView: View {
    @EnvironmentObject private var services: AppServices
    @AppStorage("presenterMode") private var presenter = false
    @AppStorage("theme") private var themeName = "accent"
    @AppStorage("lastPaletteTheme") private var lastPaletteTheme = "blue"
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("tabUsageEnabled") private var usageEnabled = true
    @AppStorage("tabMusicEnabled") private var musicEnabled = true
    @AppStorage("icloudBackup") private var icloudBackup = false
    @AppStorage("lastBackupAt") private var lastBackupAt = 0.0
    @AppStorage("musicBackup") private var musicBackup = false
    @AppStorage("lastMusicBackupAt") private var lastMusicBackupAt = 0.0
    @ObservedObject private var backupService = SettingsBackup.shared
    @State private var musicSize = ""

    private var theme: Color { themeColor(themeName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                eyebrow("TABS")
                tabToggle("Agent Usage", subtitle: "limit polling, usage stats", isOn: $usageEnabled)
                tabToggle("Music", subtitle: "player, media keys", isOn: $musicEnabled)
            }
            .card()
            // Toggling a tab creates or tears down its whole module — timers,
            // network, audio, caches — so an off tab costs nothing.
            .onChange(of: usageEnabled) { services.sync() }
            .onChange(of: musicEnabled) { services.sync() }

            VStack(alignment: .leading, spacing: 12) {
                eyebrow("GENERAL")
                HStack {
                    Text("Presenter view")
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $presenter)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme)
                }
                HStack {
                    Text("Toggle shortcut")
                        .font(.system(size: 13))
                    Spacer()
                    ShortcutRecorder()
                }
                HStack {
                    Text("Appearance")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .onChange(of: appearance) { applyAppearance(appearance) }
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                eyebrow("THEME")
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use system accent")
                            .font(.system(size: 13))
                        Text("Follows the accent color in System Settings")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { themeName == "accent" },
                        set: { themeName = $0 ? "accent" : lastPaletteTheme }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(theme)
                }
                HStack(spacing: 11) {
                    ForEach(themePalette, id: \.name) { entry in
                        swatch(entry.name, color: entry.color, help: entry.name.capitalized)
                    }
                    Spacer()
                }
                .opacity(themeName == "accent" ? 0.4 : 1)
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                eyebrow("DATA")
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App data")
                            .font(.system(size: 13))
                        Text("~/Library/Application Support/Edith")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Open") {
                        NSWorkspace.shared.open(AppData.supportDir)
                        dismissPanel()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(theme)
                    .onHover { over in
                        over ? NSCursor.pointingHand.set() : NSCursor.arrow.set()
                    }
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Back up settings to iCloud")
                            .font(.system(size: 13))
                        Text(backupSubtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $icloudBackup)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme)
                        .disabled(!AppData.cloudAvailable)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Back up music to iCloud")
                            .font(.system(size: 13))
                        Text(musicSubtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $musicBackup)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme)
                        .disabled(!AppData.cloudAvailable)
                }
            }
            .card()
            .onChange(of: icloudBackup) {
                if icloudBackup { SettingsBackup.shared.export() }
            }
            .onChange(of: musicBackup) {
                if musicBackup { SettingsBackup.shared.backupMusic() }
            }
            .onAppear { computeMusicSize() }

            HStack(spacing: 4) {
                Text("Made with ❤️ by")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Button("Pulkit") {
                    NSWorkspace.shared.open(URL(string: "https://pulkit.page")!)
                    dismissPanel()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme)
                .onHover { over in
                    over ? NSCursor.pointingHand.set() : NSCursor.arrow.set()
                }
                .help("pulkit.page")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
    }

    private func swatch(_ name: String, color: Color, help: String) -> some View {
        Button {
            themeName = name
            lastPaletteTheme = name // what the system-accent switch falls back to
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 26, height: 26)
                if themeName == name {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { over in
            over ? NSCursor.pointingHand.set() : NSCursor.arrow.set()
        }
        .help(help)
    }

    private var musicSubtitle: String {
        if !AppData.cloudAvailable { return "iCloud Drive is not available on this Mac" }
        var parts: [String] = [musicSize.isEmpty ? "measuring…" : "\(musicSize) in local/music"]
        if backupService.musicBackupRunning {
            parts.append("backing up…")
        } else if musicBackup, lastMusicBackupAt > 0 {
            let at = Date(timeIntervalSince1970: lastMusicBackupAt)
            parts.append("backed up \(at.formatted(date: .abbreviated, time: .shortened))")
        }
        return parts.joined(separator: " · ")
    }

    private func computeMusicSize() {
        Task.detached(priority: .utility) {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: Repo.musicDir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            let total = files.reduce(0) {
                $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
            let label = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
            await MainActor.run { musicSize = label }
        }
    }

    private var backupSubtitle: String {
        if !AppData.cloudAvailable { return "iCloud Drive is not available on this Mac" }
        if !icloudBackup { return "Syncs via iCloud Drive; newest copy wins across Macs" }
        if lastBackupAt > 0 {
            let at = Date(timeIntervalSince1970: lastBackupAt)
            return "Backed up \(at.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Waiting for first backup…"
    }

    private func tabToggle(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(theme)
        }
    }
}

/// Click → "Press shortcut…" → next chord with ⌘/⌥/⌃ becomes the global
/// toggle. Esc cancels. The hotkey is suspended while recording so re-picking
/// the current combo doesn't toggle the panel mid-recording.
struct ShortcutRecorder: View {
    /// Read by the app-level Esc monitor so Esc cancels recording instead of
    /// closing the panel while a capture is in progress.
    static var isRecording = false

    @State private var recording = false
    @State private var monitor: Any?
    @State private var label = HotKey.label

    var body: some View {
        Button(recording ? "Press shortcut…" : label) {
            recording ? stop() : start()
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .medium))
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(.white.opacity(recording ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 6))
        .onHover { over in
            over ? NSCursor.pointingHand.set() : NSCursor.arrow.set()
        }
        .onDisappear { if recording { stop() } }
        .help("Click, then press the new shortcut (Esc cancels)")
    }

    private func start() {
        recording = true
        Self.isRecording = true
        HotKey.unregister()
        // The panel is a non-activating panel: without forcing key status the
        // keystrokes keep going to the previously active app and the local
        // monitor never sees them.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.className.contains("MenuBarExtraWindow") }?
            .makeKeyAndOrderFront(nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil // consume while recording
        }
    }

    private func stop() {
        recording = false
        Self.isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        HotKey.register() // re-arm with whatever is stored now
        label = HotKey.label
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 { // Esc cancels
            stop()
            return
        }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // require a real modifier so plain typing can't become the hotkey
        guard flags.contains(.command) || flags.contains(.option) || flags.contains(.control)
        else { return }
        var mods = 0
        var symbols = ""
        if flags.contains(.control) { mods |= controlKey; symbols += "⌃" }
        if flags.contains(.option) { mods |= optionKey; symbols += "⌥" }
        if flags.contains(.shift) { mods |= shiftKey; symbols += "⇧" }
        if flags.contains(.command) { mods |= cmdKey; symbols += "⌘" }
        let key = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        HotKey.save(code: Int(event.keyCode), mods: mods, label: symbols + key)
        stop()
    }
}
