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
        // Switching to another app closes the panel, like system menu bar extras.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { _ in
            dismissPanel()
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
/// after actions that take the user elsewhere (browser, Finder).
func dismissPanel() {
    for window in NSApp.windows where window.className.contains("MenuBarExtraWindow") {
        window.close()
    }
}

// Shared panel styling: grouped-settings cards + tracked small-caps eyebrows.
extension View {
    /// Presenter view hides sensitive text behind a blur (readable shape, not content).
    func presenterBlur(_ on: Bool) -> some View {
        blur(radius: on ? 4 : 0)
    }

    func card() -> some View {
        padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
    }
}

func eyebrow(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 9, weight: .semibold))
        .tracking(1.2)
        .foregroundStyle(.tertiary)
}

struct RootView: View {
    @AppStorage("tab") private var tab = "usage"
    @AppStorage("presenterMode") private var presenter = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("EDITH")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if tab == "music" {
                    Button {
                        NSWorkspace.shared.open(Repo.musicDir)
                        dismissPanel()
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open music folder in Finder")
                }
                Menu {
                    Toggle("Presenter view", isOn: $presenter)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundStyle(presenter ? Color.accentColor : Color.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Settings")
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
                .help("Quit Edith (⌘Q)")
            }
            Picker("", selection: $tab) {
                Text("Agent Usage").tag("usage")
                Text("Music").tag("music")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            // match the track's corners to the capsule-shaped selection knob
            .clipShape(Capsule())
            if tab == "usage" {
                UsageView()
            } else {
                MusicView()
            }
        }
        .padding(12)
        .frame(width: 400)
        // Darken the system material — pure vibrancy washes out over light screens.
        .background(Color.black.opacity(0.55).ignoresSafeArea())
        .onExitCommand { dismissPanel() } // Esc closes the panel
    }
}
