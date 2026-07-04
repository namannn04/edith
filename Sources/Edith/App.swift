import Carbon.HIToolbox
import SwiftUI

// Repo layout the app leans on: dashboard/ holds the usage dashboard + data
// pipeline, local/ the gitignored personal files. Overridable without a
// rebuild via `defaults write com.pulkit.control-center repoPath /new/path`.
enum Repo {
    static let root: URL = {
        let override = UserDefaults.standard.string(forKey: "repoPath")
        // ponytail: hardcoded personal path; the defaults key is the escape hatch
        return URL(fileURLWithPath: override ?? "/Users/pulkit/scripts/edith")
    }()
    static var dashboard: URL { root.appendingPathComponent("dashboard/dashboard.html") }
    static var usageJSON: URL { root.appendingPathComponent("dashboard/data/usage.json") }
    static var ccUpdate: URL { root.appendingPathComponent("dashboard/cc-update") }
    static var musicDir: URL { root.appendingPathComponent("local/music") }
}

@main
struct EdithApp: App {
    // Plain let, not @StateObject: App.body must not re-evaluate on store changes.
    private let services = AppServices()

    init() {
        // Close when focus leaves the panel (click elsewhere / switch app).
        // didResignActive alone is unreliable for LSUIElement apps — the app
        // may never have been "active" — so watch the panel's key status too.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { _ in
            dismissPanel()
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: nil, queue: .main
        ) { note in
            guard let panel = note.object as? NSWindow,
                  panel.className.contains("MenuBarExtraWindow") else { return }
            // Deferred one tick: if the panel is mid-close (normal toggle) it's
            // gone by then and this no-ops; if focus genuinely left, close it
            // through the status item so the highlight clears with it.
            DispatchQueue.main.async { [weak panel] in
                if let panel, panel.isVisible { dismissPanel() }
            }
        }
        // MenuBarExtra re-anchors the panel's leading edge to the icon on every
        // open/resize/system reposition — and its anchor pass can run AFTER our
        // handler in the same tick. So: pin on key/resize/move (the move observer
        // catches the system's own repositioning; the idempotence check inside
        // centerPanelUnderIcon stops that from looping), and pin once more on
        // the next runloop turn so we always get the last word.
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResizeNotification,
            NSWindow.didMoveNotification,
        ]
        for name in names {
            NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { note in
                guard let panel = note.object as? NSWindow,
                      panel.className.contains("MenuBarExtraWindow") else { return }
                centerPanelUnderIcon(panel)
                DispatchQueue.main.async { [weak panel] in
                    if let panel, panel.isVisible { centerPanelUnderIcon(panel) }
                }
            }
        }
        HotKey.register() // ⌥⌘E toggles the panel from anywhere

        // Esc closes the panel. onExitCommand alone needs SwiftUI focus inside
        // the panel, which a non-activating panel rarely has — catch the key
        // directly. The shortcut recorder gets first claim on Esc to cancel.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53, !ShortcutRecorder.isRecording,
               NSApp.windows.contains(where: {
                   $0.className.contains("MenuBarExtraWindow") && $0.isVisible
               }) {
                dismissPanel()
                return nil
            }
            return event
        }
    }

    var body: some Scene {
        MenuBarExtra("Edith", systemImage: "eyeglasses") {
            RootView()
                .environmentObject(services)
                .preferredColorScheme(.dark)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Global toggle hotkey via Carbon — the one API that needs no accessibility
/// permission. Default ⌥⌘E; customizable from Settings (stored in defaults).
enum HotKey {
    private static var ref: EventHotKeyRef?
    private static var handlerInstalled = false

    static var code: Int {
        UserDefaults.standard.object(forKey: "hotKeyCode") as? Int ?? kVK_ANSI_E
    }
    static var mods: Int {
        UserDefaults.standard.object(forKey: "hotKeyMods") as? Int ?? (cmdKey | optionKey)
    }
    static var label: String {
        UserDefaults.standard.string(forKey: "hotKeyLabel") ?? "⌥⌘E"
    }

    static func register() {
        if !handlerInstalled {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { togglePanel() }
                return noErr
            }, 1, &eventType, nil, nil)
            handlerInstalled = true
        }
        unregister()
        let id = EventHotKeyID(signature: OSType(0x4544_4954), id: 1) // 'EDIT'
        RegisterEventHotKey(
            UInt32(code), UInt32(mods), id, GetApplicationEventTarget(), 0, &ref)
    }

    static func unregister() {
        if let ref {
            UnregisterEventHotKey(ref)
            Self.ref = nil
        }
    }

    static func save(code: Int, mods: Int, label: String) {
        UserDefaults.standard.set(code, forKey: "hotKeyCode")
        UserDefaults.standard.set(mods, forKey: "hotKeyMods")
        UserDefaults.standard.set(label, forKey: "hotKeyLabel")
    }
}

/// Synthesize a click on the status item. This is the ONLY correct way to open
/// OR close the panel: it toggles through MenuBarExtra's own state machine, so
/// the icon highlight always matches. Closing the window directly desyncs that
/// state — the icon stays lit and the next toggle gets eaten resetting it.
func clickStatusItem() {
    if let statusWindow = NSApp.windows.first(where: { $0.className.contains("StatusBarWindow") }),
       let button = firstButton(in: statusWindow.contentView) {
        button.performClick(nil)
    }
}

func togglePanel() {
    clickStatusItem() // open or close — MenuBarExtra decides from its own state
}

private func firstButton(in view: NSView?) -> NSButton? {
    guard let view else { return nil }
    if let button = view as? NSButton { return button }
    for sub in view.subviews {
        if let found = firstButton(in: sub) { return found }
    }
    return nil
}

/// Align the panel's horizontal center with the menu bar icon's center. The
/// status item is one of our own windows (NSStatusBarWindow), so its frame
/// gives the icon's exact screen position; clamp so the panel stays on-screen.
/// No-ops when already centered — that's what lets the didMove observer call
/// this without our own setFrameOrigin re-triggering an endless move loop.
func centerPanelUnderIcon(_ panel: NSWindow) {
    guard let icon = NSApp.windows.first(where: { $0.className.contains("StatusBarWindow") })
    else { return }
    var x = icon.frame.midX - panel.frame.width / 2
    if let screen = icon.screen {
        let visible = screen.visibleFrame
        x = min(max(x, visible.minX + 8), visible.maxX - panel.frame.width - 8)
    }
    guard abs(panel.frame.origin.x - x) > 0.5 else { return }
    panel.setFrameOrigin(NSPoint(x: x, y: panel.frame.origin.y))
}

/// MenuBarExtra windows don't auto-dismiss on button actions; close explicitly
/// after actions that take the user elsewhere (browser, Finder). Goes through
/// the status-item click so the icon highlight stays in sync (see above).
func dismissPanel() {
    guard NSApp.windows.contains(where: {
        $0.className.contains("MenuBarExtraWindow") && $0.isVisible
    }) else { return }
    clickStatusItem()
}

/// Hover affordance for clickable controls: pointing-hand cursor plus a soft
/// border, fill, and shadow that fade in under the pointer.
struct HoverButton: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .padding(4)
            .background(.white.opacity(hovering ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.white.opacity(hovering ? 0.16 : 0), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(hovering ? 0.35 : 0), radius: 4, y: 1)
            .onHover { over in
                hovering = over
                over ? NSCursor.pointingHand.set() : NSCursor.arrow.set()
            }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// Button style wrapping the hover chrome INSIDE the button, so the whole
/// padded/bordered area is the hit target, with pressed-state feedback.
struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(HoverButton())
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// Shared panel styling: grouped-settings cards + tracked small-caps eyebrows.
extension View {
    func hoverButton() -> some View { modifier(HoverButton()) }

    /// Presenter view hides sensitive text behind a blur (readable shape, not content).
    func presenterBlur(_ on: Bool) -> some View {
        blur(radius: on ? 4 : 0)
    }

    func card() -> some View {
        padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

func eyebrow(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 10, weight: .semibold))
        .tracking(1.4)
        .foregroundStyle(.tertiary)
}

struct RootView: View {
    @EnvironmentObject private var services: AppServices
    @AppStorage("tab") private var tab = "usage"
    @AppStorage("theme") private var themeName = "blue"
    @AppStorage("tabUsageEnabled") private var usageEnabled = true
    @AppStorage("tabMusicEnabled") private var musicEnabled = true
    @State private var showSettings = false

    // Future tabs: append here (id, title) + a store in AppServices.
    private var enabledTabs: [(id: String, title: String)] {
        var tabs: [(String, String)] = []
        if usageEnabled { tabs.append(("usage", "Agent Usage")) }
        if musicEnabled { tabs.append(("music", "Music")) }
        return tabs
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(showSettings ? "EDITH · SETTINGS" : "EDITH")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(.secondary)
                Spacer()
                if tab == "music", musicEnabled, !showSettings {
                    Button {
                        NSWorkspace.shared.open(Repo.musicDir)
                        dismissPanel()
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Open music folder in Finder")
                }
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showSettings.toggle() }
                } label: {
                    Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(showSettings ? themeColor(themeName) : Color.secondary)
                }
                .buttonStyle(HoverButtonStyle())
                .help(showSettings ? "Back" : "Settings")
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(HoverButtonStyle())
                .keyboardShortcut("q", modifiers: .command)
                .help("Quit Edith (⌘Q)")
            }
            if showSettings {
                SettingsView()
            } else {
                if enabledTabs.count > 1 {
                    Picker("", selection: $tab) {
                        ForEach(enabledTabs, id: \.id) { entry in
                            Text(entry.title).tag(entry.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.large)
                    // match the track's corners to the capsule-shaped selection knob
                    .clipShape(Capsule())
                }
                if tab == "usage", let store = services.usage {
                    UsageView().environmentObject(store)
                } else if tab == "music", let player = services.music {
                    MusicView().environmentObject(player)
                } else if enabledTabs.isEmpty {
                    Text("All tabs are off — enable one in Settings (⚙)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 28)
                }
            }
        }
        .onAppear { pinTab() }
        .onChange(of: usageEnabled) { pinTab() }
        .onChange(of: musicEnabled) { pinTab() }
        .padding(14)
        .frame(width: 480)
        // Darken the system material — pure vibrancy washes out over light screens.
        .background(Color.black.opacity(0.55).ignoresSafeArea())
        .onExitCommand { dismissPanel() } // Esc closes the panel
    }

    /// Keep the selection on a live tab when tabs get toggled in Settings.
    private func pinTab() {
        if !enabledTabs.contains(where: { $0.id == tab }), let first = enabledTabs.first {
            tab = first.id
        }
    }
}
