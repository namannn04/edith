import AppKit
import SwiftUI

/// Full-screen overlay per display while keyboard cleaning is armed/active.
/// The trackpad stays live, so a normal clickable window is enough.
final class CleaningOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    init(screen: NSScreen, rootView: some View) {
        super.init(
            contentRect: screen.frame, styleMask: [.borderless],
            backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false // the Done button must be clickable
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hasShadow = false
        contentView = NSHostingView(rootView: rootView)
        setFrame(screen.frame, display: true)
    }
}

struct CleaningOverlayView: View {
    @ObservedObject var store: SystemStore
    @AppStorage("theme") private var themeName = "accent"

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 52))
                if store.phase == .cleaning {
                    Text("Keyboard is off - clean away")
                        .font(.title)
                    Text("Auto-restores in \(store.failsafeRemaining)s")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                        .monospacedDigit()
                    Button("Done cleaning") {
                        store.stopCleaning()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeColor(themeName))
                    .controlSize(.large)
                    .onHover { over in
                        over ? NSCursor.pointingHand.set() : NSCursor.arrow.set()
                    }
                } else {
                    Text("Starting in \(store.armingCountdown)…")
                        .font(.title)
                        .monospacedDigit()
                    Text("Move your hands away from the keyboard.")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .foregroundStyle(.white)
            .padding(40)
        }
        .preferredColorScheme(.dark)
    }
}
