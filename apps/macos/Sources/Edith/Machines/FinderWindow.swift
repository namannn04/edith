import AppKit
import EdithKit
import SwiftUI

struct FinderWindowView: View {
    @StateObject private var model: FinderModel
    @Environment(\.colorScheme) private var scheme
    @State private var confirmDelete = false
    @FocusState private var listFocused: Bool

    private var dark: Bool { scheme == .dark }

    init(session: MachineSession, path: String? = nil) {
        _model = StateObject(wrappedValue: FinderModel(session: session, path: path))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            pathBar
            Divider().opacity(0.5)
            statusBar
        }
        .background(DashSkin.paper(dark))
        .focusable()
        .focused($listFocused)
        .task {
            listFocused = true
            await model.load()
        }
        .onChange(of: model.session.state.isConnected) { _, connected in
            if connected { model.refresh() }
        }
        .overlay {
            if model.quickLookPath != nil {
                QuickLookOverlay(model: model)
            }
        }
        .onKeyPress(.space) {
            guard model.quickLookPath == nil else {
                model.quickLookPath = nil
                return .handled
            }
            model.quickLookPath = model.selectedEntries.first?.path
            return .handled
        }
        .onKeyPress(.escape) {
            guard model.quickLookPath != nil else { return .ignored }
            model.quickLookPath = nil
            return .handled
        }
        .onKeyPress(.upArrow) { arrow(-1) }
        .onKeyPress(.downArrow) { arrow(1) }
        .onKeyPress(.return) {
            guard let entry = model.selectedEntries.first else { return .ignored }
            model.beginRename(entry)
            return .handled
        }
        .onKeyPress(characters: .alphanumerics) { press in
            guard press.modifiers.isEmpty else { return .ignored }
            model.typeSelect(press.characters)
            return .handled
        }
        .confirmationDialog(
            "Delete \(model.selection.count) item\(model.selection.count == 1 ? "" : "s")?",
            isPresented: $confirmDelete, titleVisibility: .visible
        ) {
            Button("Delete Immediately", role: .destructive) {
                Task { await model.trashSelection(permanently: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func arrow(_ offset: Int) -> KeyPress.Result {
        model.moveSelection(by: offset, extend: NSEvent.modifierFlags.contains(.shift))
        return .handled
    }

    private var toolbar: some View {
        HStack(spacing: UIScale.pt(8)) {
            HStack(spacing: UIScale.pt(2)) {
                Button {
                    model.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!model.canGoBack)
                .help("Back (⌘[)")
                Button {
                    model.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!model.canGoForward)
                .help("Forward (⌘])")
                Button {
                    model.goUp()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!model.canGoUp)
                .help("Enclosing folder (⌘↑)")
                Button {
                    model.goHome()
                } label: {
                    Image(systemName: "house")
                }
                .help("Home folder")
            }
            .buttonStyle(HoverButtonStyle())

            Picker("", selection: viewModeBinding) {
                ForEach(FileViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: UIScale.pt(90))
            .help("View as icons (⌘1) or list (⌘2)")

            Menu {
                ForEach(FileSortKey.allCases, id: \.self) { key in
                    Button {
                        if model.sortKey == key {
                            model.sortAscending.toggle()
                        } else {
                            model.sortKey = key
                            model.sortAscending = true
                        }
                    } label: {
                        Label(
                            key.title,
                            systemImage: model.sortKey == key
                                ? (model.sortAscending ? "chevron.up" : "chevron.down") : "")
                    }
                }
                Divider()
                Toggle("Show Hidden Files", isOn: $model.showHidden)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Sort")

            Spacer(minLength: UIScale.pt(4))

            SearchField(placeholder: "Search this folder", text: $model.searchQuery)
                .frame(width: UIScale.pt(200))
                .onSubmit { Task { await model.runSearch() } }
                .onChange(of: model.searchQuery) { _, value in
                    if value.isEmpty { model.searchResults = nil }
                }

            Menu {
                Button("New Folder") { Task { await model.newFolder() } }
                Button("Upload Files…") { chooseUpload() }
                if !model.selection.isEmpty {
                    Divider()
                    if !model.session.isLocal {
                        Button("Download…") { chooseDownload() }
                    }
                    Button("Duplicate") { Task { await model.duplicateSelection() } }
                    Button("Copy Path") { model.copyPaths() }
                    if model.session.isLocal {
                        Button("Reveal in Finder") { model.revealInFinder() }
                    }
                    Divider()
                    Button("Move to Trash") {
                        Task { await model.trashSelection(permanently: false) }
                    }
                    Button("Delete Immediately…", role: .destructive) { confirmDelete = true }
                }
                Divider()
                Button("Refresh") { model.refresh() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Actions")
        }
        .padding(.horizontal, UIScale.pt(12))
        .padding(.vertical, UIScale.pt(8))
        .background(.regularMaterial)
    }

    private var viewModeBinding: Binding<FileViewMode> {
        Binding(get: { model.viewMode }, set: { model.viewMode = $0 })
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            if model.viewMode == .icon {
                FinderIconView(model: model)
            } else {
                FinderListView(model: model)
            }
            if model.loading, model.entries.isEmpty {
                ProgressView().controlSize(.small)
            } else if model.visibleEntries.isEmpty, !model.loading {
                Text(model.errorMessage ?? "This folder is empty.")
                    .font(.system(size: UIScale.pt(12)))
                    .foregroundStyle(DashSkin.inkFaint(dark))
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            Task { await model.upload(urls) }
            return true
        }
    }

    private var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UIScale.pt(3)) {
                ForEach(FileListing.breadcrumbs(for: model.path), id: \.path) { crumb in
                    Button {
                        model.navigate(to: crumb.path)
                    } label: {
                        HStack(spacing: UIScale.pt(4)) {
                            Image(
                                systemName: crumb.path == "/" ? "externaldrive" : "folder"
                            )
                            .font(.system(size: UIScale.pt(9.5)))
                            Text(crumb.name)
                                .font(.system(size: UIScale.pt(11)))
                        }
                        .foregroundStyle(
                            crumb.path == model.path
                                ? DashSkin.ink(dark) : DashSkin.inkFaint(dark))
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    if crumb.path != model.path {
                        Image(systemName: "chevron.compact.right")
                            .font(.system(size: UIScale.pt(9)))
                            .foregroundStyle(DashSkin.inkFaint(dark).opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, UIScale.pt(12))
            .padding(.vertical, UIScale.pt(5))
        }
        .background(.thinMaterial)
    }

    private var statusBar: some View {
        HStack(spacing: UIScale.pt(8)) {
            if let message = model.statusMessage ?? model.errorMessage {
                Text(message)
                    .font(.system(size: UIScale.pt(10.5)))
                    .foregroundStyle(
                        model.errorMessage == nil ? DashSkin.inkFaint(dark) : DashSkin.danger
                    )
                    .lineLimit(1)
            } else {
                Text(model.statusLine)
                    .font(.system(size: UIScale.pt(10.5)))
                    .foregroundStyle(DashSkin.inkFaint(dark))
            }
            Spacer(minLength: 0)
            if model.loading {
                ProgressView().controlSize(.small).scaleEffect(0.6)
            }
        }
        .padding(.horizontal, UIScale.pt(12))
        .padding(.vertical, UIScale.pt(4))
        .background(.thinMaterial)
    }

    private func chooseUpload() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { await model.upload(urls) }
    }

    private func chooseDownload() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Download Here"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.download(to: url) }
    }
}

struct FinderRowContextMenu: View {
    @ObservedObject var model: FinderModel
    let entry: RemoteFileEntry

    var body: some View {
        Button("Open") { model.open(entry) }
        if entry.isDirectory {
            Button("Open in New Window") {
                FinderWindow.open(session: model.session, path: entry.path)
            }
        } else {
            Button("Quick Look") { model.quickLookPath = entry.path }
        }
        Divider()
        Button("Rename") { model.beginRename(entry) }
        Button("Duplicate") { Task { await model.duplicateSelection() } }
        Button("Copy Path") { model.copyPaths() }
        Divider()
        Button("Move to Trash", role: .destructive) {
            Task { await model.trashSelection(permanently: false) }
        }
    }
}

@MainActor
enum FinderWindow {
    private static var windows: [String: NSWindow] = [:]

    static func open(session: MachineSession, path: String? = nil) {
        let key = session.machine.id.uuidString + (path ?? "")
        if let existing = windows[key] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 620),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = session.machine.name
        window.subtitle = path ?? (session.isLocal ? "Home" : "Files")
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 620, height: 400)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "EdithFinder"
        let hosting = NSHostingController(
            rootView: ZoomableRoot { FinderWindowView(session: session, path: path) })
        hosting.sizingOptions = []
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 940, height: 620))
        window.setFrameAutosaveName("EdithFinderWindow")
        if window.frame.origin == .zero { window.center() }
        window.delegate = FinderWindowDelegate.shared
        windows[key] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func forget(_ window: NSWindow) {
        windows = windows.filter { $0.value !== window }
    }
}

@MainActor
final class FinderWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = FinderWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        FinderWindow.forget(window)
    }
}
