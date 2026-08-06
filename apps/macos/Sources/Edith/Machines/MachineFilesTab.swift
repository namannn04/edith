import AppKit
import AVKit
import EdithKit
import PDFKit
import Quartz
import SwiftUI
import UniformTypeIdentifiers

enum FileIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(for entry: RemoteFileEntry) -> NSImage {
        if entry.isDirectory { return cached(key: "__folder", type: .folder) }
        if entry.kind == .symlink { return cached(key: "__link", type: .symbolicLink) }
        let ext = entry.fileExtension
        guard !ext.isEmpty else { return cached(key: "__data", type: .data) }
        if let type = UTType(filenameExtension: ext) {
            return cached(key: ext, type: type)
        }
        return cached(key: "__data", type: .data)
    }

    private static func cached(key: String, type: UTType) -> NSImage {
        if let existing = cache[key] { return existing }
        let image = NSWorkspace.shared.icon(for: type)
        cache[key] = image
        return image
    }
}

struct MachineFilesTab: View {
    @ObservedObject var session: MachineSession
    @Environment(\.colorScheme) private var scheme

    private var dark: Bool { scheme == .dark }

    var body: some View {
        VStack(spacing: UIScale.pt(14)) {
            Image(systemName: "folder")
                .font(.system(size: UIScale.pt(34)))
                .foregroundStyle(DashSkin.inkFaint(dark))
            Text("Files open in their own window")
                .font(DashSkin.serif(18))
                .foregroundStyle(DashSkin.ink(dark))
            Text(
                "Browse, preview, and move files in a full window so you can keep it beside "
                    + "everything else."
            )
            .font(.system(size: UIScale.pt(12)))
            .foregroundStyle(DashSkin.inkFaint(dark))
            .multilineTextAlignment(.center)
            .frame(maxWidth: UIScale.pt(400))
            Button("Open Files Window") {
                FinderWindow.open(session: session)
            }
            .pointerCursor()
            .disabled(!session.state.isConnected)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard session.state.isConnected else { return }
            FinderWindow.open(session: session)
        }
    }
}
