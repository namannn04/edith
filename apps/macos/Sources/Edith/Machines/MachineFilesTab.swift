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

@MainActor
final class FileBrowserModel: ObservableObject {
    @Published var path: String
    @Published private(set) var entries: [RemoteFileEntry] = []
    @Published private(set) var loading = false
    @Published var error: String?
    @Published var showHidden = false
    @Published var query = ""
    @Published var selection: RemoteFileEntry?
    @Published var transfer: String?

    private var history: [String] = []
    private var future: [String] = []
    private let session: MachineSession

    init(session: MachineSession) {
        self.session = session
        path =
            session.isLocal
            ? FileManager.default.homeDirectoryForCurrentUser.path : "/"
    }

    var canGoBack: Bool { !history.isEmpty }
    var canGoUp: Bool { FileListing.parentPath(of: path) != nil }

    var visibleEntries: [RemoteFileEntry] {
        let base = showHidden ? entries : entries.filter { !$0.isHidden }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    func load() async {
        loading = true
        error = nil
        let result = await session.listFiles(path: path)
        loading = false
        switch result {
        case let .success(items):
            entries = items
        case let .failure(failure):
            entries = []
            error = failure.localizedDescription
        }
    }

    func open(_ entry: RemoteFileEntry) {
        guard entry.isDirectory || entry.kind == .symlink else {
            selection = entry
            return
        }
        navigate(to: entry.path)
    }

    func navigate(to newPath: String) {
        history.append(path)
        future.removeAll()
        path = newPath
        selection = nil
        Task { await load() }
    }

    func goUp() {
        guard let parent = FileListing.parentPath(of: path) else { return }
        navigate(to: parent)
    }

    func goBack() {
        guard let previous = history.popLast() else { return }
        future.append(path)
        path = previous
        selection = nil
        Task { await load() }
    }

    func goHome() {
        navigate(
            to: session.isLocal
                ? FileManager.default.homeDirectoryForCurrentUser.path
                : "~")
    }

    func refresh() {
        Task { await load() }
    }

    func delete(_ entry: RemoteFileEntry) async {
        let command =
            entry.isDirectory
            ? "rm -rf \(ShellQuote.quote(entry.path))" : "rm -f \(ShellQuote.quote(entry.path))"
        let result = await session.runCommand(command)
        if case let .failure(failure) = result {
            error = failure.localizedDescription
        } else {
            if selection?.id == entry.id { selection = nil }
            await load()
        }
    }

    func makeDirectory(named name: String) async {
        let target = FileListing.join(parent: path, name: name)
        let result = await session.runCommand("mkdir -p \(ShellQuote.quote(target))")
        if case let .failure(failure) = result {
            error = failure.localizedDescription
        } else {
            await load()
        }
    }

    func rename(_ entry: RemoteFileEntry, to name: String) async {
        let target = FileListing.join(parent: path, name: name)
        let result = await session.runCommand(
            "mv \(ShellQuote.quote(entry.path)) \(ShellQuote.quote(target))")
        if case let .failure(failure) = result {
            error = failure.localizedDescription
        } else {
            await load()
        }
    }

    func download(_ entry: RemoteFileEntry, to destination: URL) async {
        guard let connection = session.connectionRef else {
            try? FileManager.default.copyItem(
                at: URL(fileURLWithPath: entry.path), to: destination)
            return
        }
        transfer = "Downloading \(entry.name)…"
        do {
            try await connection.download(remotePath: entry.path, to: destination)
            transfer = "Saved \(entry.name)"
        } catch {
            transfer = nil
            self.error = error.localizedDescription
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            transfer = nil
        }
    }

    func upload(_ localURL: URL) async {
        let target = FileListing.join(parent: path, name: localURL.lastPathComponent)
        guard let connection = session.connectionRef else {
            try? FileManager.default.copyItem(at: localURL, to: URL(fileURLWithPath: target))
            await load()
            return
        }
        transfer = "Uploading \(localURL.lastPathComponent)…"
        do {
            try await connection.upload(localURL: localURL, toRemotePath: target)
            transfer = nil
            await load()
        } catch {
            transfer = nil
            self.error = error.localizedDescription
        }
    }
}

struct MachineFilesTab: View {
    @ObservedObject var session: MachineSession
    @StateObject private var model: FileBrowserModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.compactLayout) private var compact
    @State private var pendingDelete: RemoteFileEntry?
    @State private var newFolderPresented = false
    @State private var newFolderName = ""

    private var dark: Bool { scheme == .dark }

    init(session: MachineSession) {
        self.session = session
        _model = StateObject(wrappedValue: FileBrowserModel(session: session))
    }

    var body: some View {
        HSplitView {
            listPane
                .frame(minWidth: UIScale.pt(300))
            FilePreviewPane(entry: model.selection, session: session)
                .frame(minWidth: UIScale.pt(280))
        }
        .task(id: session.state.isConnected) {
            if session.state.isConnected { await model.load() }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.name ?? "item")?",
            isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let entry = pendingDelete {
                    Task { await model.delete(entry) }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(
                pendingDelete?.isDirectory == true
                    ? "The folder and everything inside it is removed on the machine."
                    : "The file is removed on the machine.")
        }
        .alert("New folder", isPresented: $newFolderPresented) {
            TextField("Name", text: $newFolderName)
            Button("Create") {
                let name = newFolderName.trimmingCharacters(in: .whitespaces)
                newFolderName = ""
                guard !name.isEmpty else { return }
                Task { await model.makeDirectory(named: name) }
            }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
    }

    private var listPane: some View {
        VStack(spacing: UIScale.pt(0)) {
            toolbar
            breadcrumbs
            Divider().opacity(0.3)
            if let error = model.error {
                noticeBar(error, color: DashSkin.danger)
            }
            if let transfer = model.transfer {
                noticeBar(transfer, color: DashSkin.accent(dark))
            }
            fileList
        }
        .background(DashSkin.paper(dark))
    }

    private var toolbar: some View {
        HStack(spacing: UIScale.pt(8)) {
            Button {
                model.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(HoverButtonStyle())
            .disabled(!model.canGoBack)
            .help("Back")
            Button {
                model.goUp()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(HoverButtonStyle())
            .disabled(!model.canGoUp)
            .help("Enclosing folder")
            Button {
                model.goHome()
            } label: {
                Image(systemName: "house")
            }
            .buttonStyle(HoverButtonStyle())
            .help("Home folder")
            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(HoverButtonStyle())
            .help("Refresh")
            SearchField(placeholder: "Filter", text: $model.query)
                .frame(maxWidth: UIScale.pt(200))
            Spacer(minLength: 0)
            Toggle("Hidden", isOn: $model.showHidden)
                .toggleStyle(.checkbox)
                .font(.system(size: UIScale.pt(11)))
            Menu {
                Button("New folder…") { newFolderPresented = true }
                Button("Upload file…") { chooseUpload() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, PageMetrics.gutter(compact))
        .padding(.bottom, UIScale.pt(8))
    }

    private var breadcrumbs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UIScale.pt(2)) {
                ForEach(FileListing.breadcrumbs(for: model.path), id: \.path) { crumb in
                    Button {
                        model.navigate(to: crumb.path)
                    } label: {
                        Text(crumb.name)
                            .font(.system(size: UIScale.pt(11.5)))
                            .foregroundStyle(
                                crumb.path == model.path
                                    ? DashSkin.ink(dark) : DashSkin.inkFaint(dark))
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    if crumb.path != model.path {
                        Image(systemName: "chevron.right")
                            .font(.system(size: UIScale.pt(8)))
                            .foregroundStyle(DashSkin.inkFaint(dark).opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, PageMetrics.gutter(compact))
            .padding(.bottom, UIScale.pt(8))
        }
    }

    private func noticeBar(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: UIScale.pt(11)))
            .foregroundStyle(DashSkin.inkSoft(dark))
            .padding(.horizontal, PageMetrics.gutter(compact))
            .padding(.vertical, UIScale.pt(7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12))
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: UIScale.pt(0)) {
                if model.loading, model.entries.isEmpty {
                    HStack(spacing: UIScale.pt(8)) {
                        ProgressView().controlSize(.small)
                        Text("Reading folder…")
                            .font(.system(size: UIScale.pt(12)))
                            .foregroundStyle(DashSkin.inkFaint(dark))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, UIScale.pt(30))
                } else if model.visibleEntries.isEmpty {
                    Text(session.state.isConnected ? "Nothing here." : "Connect to browse files.")
                        .font(.system(size: UIScale.pt(12)))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, UIScale.pt(30))
                }
                ForEach(model.visibleEntries) { entry in
                    FileRow(
                        entry: entry, dark: dark, selected: model.selection?.id == entry.id,
                        onOpen: { model.open(entry) },
                        onDownload: { download(entry) },
                        onDelete: { pendingDelete = entry })
                }
            }
            .padding(.horizontal, PageMetrics.gutter(compact))
            .padding(.bottom, UIScale.pt(16))
        }
    }

    private func download(_ entry: RemoteFileEntry) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = entry.name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.download(entry, to: url) }
    }

    private func chooseUpload() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.upload(url) }
    }
}

private struct FileRow: View {
    let entry: RemoteFileEntry
    let dark: Bool
    let selected: Bool
    let onOpen: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: UIScale.pt(9)) {
            Image(nsImage: FileIcons.icon(for: entry))
                .resizable()
                .frame(width: UIScale.pt(17), height: UIScale.pt(17))
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.name)
                    .font(.system(size: UIScale.pt(12.5)))
                    .foregroundStyle(DashSkin.ink(dark))
                    .lineLimit(1)
                if let target = entry.linkTarget {
                    Text("→ \(target)")
                        .font(DashSkin.mono(9.5))
                        .foregroundStyle(DashSkin.inkFaint(dark))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: UIScale.pt(8))
            if !entry.isDirectory {
                Text(ByteFormatter.string(entry.sizeBytes))
                    .font(DashSkin.mono(10.5))
                    .foregroundStyle(DashSkin.inkFaint(dark))
                    .frame(width: UIScale.pt(70), alignment: .trailing)
            }
            if let modified = entry.modified {
                Text(modified.formatted(date: .abbreviated, time: .omitted))
                    .font(DashSkin.mono(10))
                    .foregroundStyle(DashSkin.inkFaint(dark))
                    .frame(width: UIScale.pt(86), alignment: .trailing)
            }
            if entry.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: UIScale.pt(9)))
                    .foregroundStyle(DashSkin.inkFaint(dark))
                    .frame(width: UIScale.pt(12))
            } else {
                Color.clear.frame(width: UIScale.pt(12))
            }
        }
        .padding(.vertical, UIScale.pt(5))
        .padding(.horizontal, UIScale.pt(7))
        .background(
            RoundedRectangle(cornerRadius: UIScale.pt(7))
                .fill(
                    selected
                        ? DashSkin.accent(dark).opacity(0.16)
                        : (hovering ? DashSkin.inkFaint(dark).opacity(0.08) : .clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { onOpen() }
        .onTapGesture { onOpen() }
        .pointerCursor()
        .contextMenu {
            if !entry.isDirectory {
                Button("Download…", action: onDownload)
            }
            Button("Copy path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.path, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
