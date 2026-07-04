import AppKit
import Carbon.HIToolbox
import SwiftUI

// The app theme: one accent used by the limit rings, the activity calendar,
// and the player controls. Stored by name in UserDefaults ("theme").
let themePalette: [(name: String, color: Color)] = [
    ("blue", .blue), ("teal", .teal), ("green", .green),
    ("purple", .purple), ("pink", .pink), ("orange", .orange),
]

func themeColor(_ name: String) -> Color {
    themePalette.first { $0.name == name }?.color ?? .blue
}

struct SettingsView: View {
    @EnvironmentObject private var services: AppServices
    @AppStorage("presenterMode") private var presenter = false
    @AppStorage("theme") private var themeName = "blue"
    @AppStorage("tabUsageEnabled") private var usageEnabled = true
    @AppStorage("tabMusicEnabled") private var musicEnabled = true
    @AppStorage("icloudBackup") private var icloudBackup = false
    @AppStorage("lastBackupAt") private var lastBackupAt = 0.0

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
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                eyebrow("THEME")
                HStack(spacing: 12) {
                    ForEach(themePalette, id: \.name) { entry in
                        Button {
                            themeName = entry.name
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(entry.color)
                                    .frame(width: 26, height: 26)
                                if themeName == entry.name {
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
                        .help(entry.name.capitalized)
                    }
                    Spacer()
                }
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
            }
            .card()
            .onChange(of: icloudBackup) {
                if icloudBackup { SettingsBackup.shared.export() }
            }
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
