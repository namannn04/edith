import AppKit
import EdithKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class FinderModel: ObservableObject {
    @Published var path: String
    @Published private(set) var entries: [RemoteFileEntry] = []
    @Published private(set) var loading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var selection: Set<String> = []
    @Published var renaming: String?
    @Published var renameText = ""
    @Published var quickLookPath: String?
    @Published var freeSpaceKB: Int64?
    @Published var searchQuery = ""
    @Published var searchResults: [RemoteFileEntry]?

    @AppStorage("finderViewMode", store: SharedDefaults.store) var viewModeRaw =
        FileViewMode.list.rawValue
    @AppStorage("finderSortKey", store: SharedDefaults.store) var sortKeyRaw =
        FileSortKey.name.rawValue
    @AppStorage("finderSortAscending", store: SharedDefaults.store) var sortAscending = true
    @AppStorage("finderShowHidden", store: SharedDefaults.store) var showHidden = false
    @AppStorage("finderIconSize", store: SharedDefaults.store) var iconSize = 72.0

    let session: MachineSession
    private var history: [String] = []
    private var future: [String] = []
    private var anchor: String?
    private var typeBuffer = ""
    private var typeBufferAt = Date.distantPast
    private var loadToken = 0

    init(session: MachineSession, path: String? = nil) {
        self.session = session
        self.path =
            path
            ?? (session.isLocal ? FileManager.default.homeDirectoryForCurrentUser.path : "~")
    }

    var viewMode: FileViewMode {
        get { FileViewMode(rawValue: viewModeRaw) ?? .list }
        set { viewModeRaw = newValue.rawValue }
    }

    var sortKey: FileSortKey {
        get { FileSortKey(rawValue: sortKeyRaw) ?? .name }
        set { sortKeyRaw = newValue.rawValue }
    }

    var canGoBack: Bool { !history.isEmpty }
    var canGoForward: Bool { !future.isEmpty }
    var canGoUp: Bool { FileListing.parentPath(of: path) != nil }

    var visibleEntries: [RemoteFileEntry] {
        if let searchResults { return searchResults }
        let base = showHidden ? entries : entries.filter { !$0.isHidden }
        return FileSorting.sort(base, by: sortKey, ascending: sortAscending)
    }

    var selectedEntries: [RemoteFileEntry] {
        visibleEntries.filter { selection.contains($0.path) }
    }

    var statusLine: String {
        let total = visibleEntries.count
        var text = "\(total) item\(total == 1 ? "" : "s")"
        if selection.count == 1, let entry = selectedEntries.first {
            text += ", \(entry.name) selected"
        } else if selection.count > 1 {
            let bytes = selectedEntries.reduce(Int64(0)) { $0 + $1.sizeBytes }
            text += ", \(selection.count) selected (\(ByteFormatter.string(bytes)))"
        }
        if let freeSpaceKB {
            text += "  ·  \(ByteFormatter.string(freeSpaceKB * 1024)) available"
        }
        return text
    }

    func load() async {
        loadToken += 1
        let token = loadToken
        loading = true
        errorMessage = nil
        let result = await session.listFiles(path: path)
        guard token == loadToken else { return }
        loading = false
        switch result {
        case let .success(items):
            entries = items
            selection = selection.filter { path in items.contains { $0.path == path } }
        case let .failure(failure):
            entries = []
            errorMessage = failure.localizedDescription
        }
        await loadFreeSpace()
    }

    private func loadFreeSpace() async {
        if session.isLocal {
            let values = try? URL(fileURLWithPath: path).resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            freeSpaceKB = (values?.volumeAvailableCapacityForImportantUsage).map { $0 / 1024 }
            return
        }
        let result = await session.runCommand(
            FileOperations.freeSpaceCommand(path: path), timeout: 20)
        if case let .success(output) = result {
            freeSpaceKB = Int64(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func navigate(to newPath: String, recordHistory: Bool = true) {
        guard newPath != path else { return }
        if recordHistory {
            history.append(path)
            future.removeAll()
        }
        path = newPath
        selection = []
        anchor = nil
        searchResults = nil
        searchQuery = ""
        Task { await load() }
    }

    func goBack() {
        guard let previous = history.popLast() else { return }
        future.append(path)
        navigate(to: previous, recordHistory: false)
    }

    func goForward() {
        guard let next = future.popLast() else { return }
        history.append(path)
        navigate(to: next, recordHistory: false)
    }

    func goUp() {
        guard let parent = FileListing.parentPath(of: path) else { return }
        navigate(to: parent)
    }

    func goHome() {
        navigate(
            to: session.isLocal ? FileManager.default.homeDirectoryForCurrentUser.path : "~")
    }

    func refresh() {
        Task { await load() }
    }

    func open(_ entry: RemoteFileEntry) {
        if entry.isDirectory || entry.kind == .symlink {
            navigate(to: entry.path)
        } else {
            quickLookPath = entry.path
        }
    }

    func openSelection() {
        guard let entry = selectedEntries.first else { return }
        open(entry)
    }

    func click(_ entry: RemoteFileEntry, modifiers: EventModifiers) {
        if modifiers.contains(.shift) {
            selection = FileSelectionMath.rangeSelection(
                in: visibleEntries, from: anchor, to: entry.path)
        } else if modifiers.contains(.command) {
            selection = FileSelectionMath.toggled(selection, path: entry.path)
            anchor = entry.path
        } else {
            selection = [entry.path]
            anchor = entry.path
        }
    }

    func selectAll() {
        selection = Set(visibleEntries.map(\.path))
    }

    func moveSelection(by offset: Int, extend: Bool) {
        let items = visibleEntries
        guard !items.isEmpty else { return }
        let currentIndex =
            selection.isEmpty
            ? -1 : (items.firstIndex { $0.path == (anchor ?? selection.first) } ?? 0)
        let nextIndex = max(0, min(items.count - 1, currentIndex + offset))
        let target = items[nextIndex]
        if extend {
            selection.insert(target.path)
        } else {
            selection = [target.path]
        }
        anchor = target.path
        if quickLookPath != nil { quickLookPath = target.path }
    }

    func typeSelect(_ characters: String) {
        let now = Date()
        if now.timeIntervalSince(typeBufferAt) > 0.75 { typeBuffer = "" }
        typeBufferAt = now
        typeBuffer += characters.lowercased()
        guard
            let match = FileSelectionMath.typeSelectMatch(
                in: visibleEntries, prefix: typeBuffer, after: anchor)
        else { return }
        selection = [match]
        anchor = match
    }

    func beginRename(_ entry: RemoteFileEntry) {
        renaming = entry.path
        renameText = entry.name
    }

    func commitRename() async {
        guard let renaming, let entry = entries.first(where: { $0.path == renaming }) else {
            return
        }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.renaming = nil
        guard !trimmed.isEmpty, trimmed != entry.name, !trimmed.contains("/") else { return }
        let target = FileListing.join(parent: path, name: trimmed)
        await run(FileOperations.renameCommand(path: entry.path, to: target), reload: true)
    }

    func newFolder() async {
        let name = FileOperations.newFolderName(existing: entries)
        let target = FileListing.join(parent: path, name: name)
        await run(FileOperations.makeDirectoryCommand(path: target), reload: true)
        if let created = entries.first(where: { $0.path == target }) {
            selection = [target]
            beginRename(created)
        }
    }

    func duplicateSelection() async {
        for entry in selectedEntries {
            let name = FileOperations.duplicateName(of: entry.name, existing: entries)
            let target = FileListing.join(parent: path, name: name)
            await run(
                "cp -a \(ShellQuote.quote(entry.path)) \(ShellQuote.quote(target))",
                reload: false)
        }
        await load()
    }

    func trashSelection(permanently: Bool) async {
        let paths = selectedEntries.map(\.path)
        guard !paths.isEmpty else { return }
        if session.isLocal {
            for path in paths {
                let url = URL(fileURLWithPath: path)
                if permanently {
                    try? FileManager.default.removeItem(at: url)
                } else {
                    try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
                }
            }
            selection = []
            await load()
            return
        }
        let command =
            permanently
            ? FileOperations.deleteCommand(paths: paths)
            : FileOperations.trashCommand(paths: paths)
        selection = []
        await run(command, reload: true)
    }

    func copyPaths() {
        let paths = selectedEntries.map(\.path)
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
        statusMessage = "Copied \(paths.count) path\(paths.count == 1 ? "" : "s")"
    }

    func revealInFinder() {
        guard session.isLocal else { return }
        let urls = selectedEntries.map { URL(fileURLWithPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func download(to destination: URL) async {
        guard let connection = session.connectionRef else { return }
        for entry in selectedEntries where !entry.isDirectory {
            statusMessage = "Downloading \(entry.name)…"
            let target = destination.appendingPathComponent(entry.name)
            do {
                try await connection.download(remotePath: entry.path, to: target)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        statusMessage = nil
    }

    func upload(_ urls: [URL]) async {
        guard let connection = session.connectionRef else {
            for url in urls {
                let target = FileListing.join(parent: path, name: url.lastPathComponent)
                try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: target))
            }
            await load()
            return
        }
        for url in urls {
            statusMessage = "Uploading \(url.lastPathComponent)…"
            let target = FileListing.join(parent: path, name: url.lastPathComponent)
            do {
                try await connection.upload(localURL: url, toRemotePath: target)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        statusMessage = nil
        await load()
    }

    func runSearch() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = nil
            return
        }
        if session.isLocal {
            let matches = entries.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            searchResults = matches
            return
        }
        let result = await session.runCommand(
            FileOperations.searchCommand(path: path, query: trimmed), timeout: 45)
        guard case let .success(output) = result else { return }
        searchResults = output.split(separator: "\n").map { line in
            let full = String(line)
            return RemoteFileEntry(
                name: (full as NSString).lastPathComponent, path: full, kind: .file,
                sizeBytes: 0)
        }
    }

    private func run(_ command: String, reload: Bool) async {
        let result = await session.runCommand(command, timeout: 120)
        if case let .failure(failure) = result {
            errorMessage = failure.localizedDescription
        }
        if reload { await load() }
    }

    func itemProvider(for entry: RemoteFileEntry) -> NSItemProvider {
        if session.isLocal {
            return NSItemProvider(contentsOf: URL(fileURLWithPath: entry.path))
                ?? NSItemProvider()
        }
        let provider = NSItemProvider()
        provider.suggestedName = entry.name
        let type = UTType(filenameExtension: entry.fileExtension) ?? .data
        let contentType = type.conforms(to: .data) ? type : .data
        let connection = session.connectionRef
        let remotePath = entry.path
        let name = entry.name
        provider.registerFileRepresentation(
            forTypeIdentifier: contentType.identifier, fileOptions: [], visibility: .all
        ) { completion in
            let progress = Progress(totalUnitCount: max(1, entry.sizeBytes))
            let task = Task.detached {
                guard let connection else {
                    completion(nil, false, FinderTransferError.notConnected)
                    return
                }
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                try? FileManager.default.createDirectory(
                    at: destination, withIntermediateDirectories: true)
                let fileURL = destination.appendingPathComponent(name)
                do {
                    try await connection.download(remotePath: remotePath, to: fileURL) { sent in
                        progress.completedUnitCount = sent
                    }
                    completion(fileURL, false, nil)
                } catch {
                    completion(nil, false, error)
                }
            }
            progress.cancellationHandler = { task.cancel() }
            return progress
        }
        return provider
    }
}

enum FinderTransferError: LocalizedError {
    case notConnected

    var errorDescription: String? { "The machine is not connected." }
}
