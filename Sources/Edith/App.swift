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
    // Plain lets, not @StateObject: App.body must not re-evaluate on store changes.
    private let usage = UsageStore()
    private let music = MusicPlayer()

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
    }

    var body: some Scene {
        MenuBarExtra("Edith", systemImage: "eyeglasses") {
            RootView()
                .environmentObject(usage)
                .environmentObject(music)
                .preferredColorScheme(.dark)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Global ⌥⌘E hotkey via Carbon — the one API that needs no accessibility
/// permission. Toggling works by synthesizing a click on our own status item,
/// so open/close behaves exactly like a real click (centering included).
enum HotKey {
    private static var ref: EventHotKeyRef?

    static func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { togglePanel() }
            return noErr
        }, 1, &eventType, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x4544_4954), id: 1) // 'EDIT'
        RegisterEventHotKey(
            UInt32(kVK_ANSI_E), UInt32(cmdKey | optionKey), id,
            GetApplicationEventTarget(), 0, &ref)
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
    @AppStorage("tab") private var tab = "usage"
    @AppStorage("presenterMode") private var presenter = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("EDITH")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(.secondary)
                Spacer()
                if tab == "music" {
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
                Menu {
                    Toggle("Presenter view", isOn: $presenter)
                    Divider()
                    Text("Toggle panel: ⌥⌘E")
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(presenter ? Color.accentColor : Color.secondary)
                        .hoverButton() // on the label so the padded area stays clickable
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Settings")
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
            Picker("", selection: $tab) {
                Text("Agent Usage").tag("usage")
                Text("Music").tag("music")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)
            // match the track's corners to the capsule-shaped selection knob
            .clipShape(Capsule())
            if tab == "usage" {
                UsageView()
            } else {
                MusicView()
            }
        }
        .padding(14)
        .frame(width: 480)
        // Darken the system material — pure vibrancy washes out over light screens.
        .background(Color.black.opacity(0.55).ignoresSafeArea())
        .onExitCommand { dismissPanel() } // Esc closes the panel
    }
}
