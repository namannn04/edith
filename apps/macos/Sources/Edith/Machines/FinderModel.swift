import AppKit
import EdithKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class FinderModel: ObservableObject {
    @Published var path: String
    @Published var entries: [RemoteFileEntry] = []
    @Published private(set) var loading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var selection: Set<String> = [] {
        didSet { syncQuickLookToSelection() }
    }
    @Published var renaming: String?
    @Published var renameText = ""
    @Published var quickLookPath: String?
    @Published var freeSpaceKB: Int64?
    @Published var searchQuery = ""
    @Published var searchResults: [RemoteFileEntry]?
    @Published var places: [FilePlaceSection] = []
    @Published var infoTarget: RemoteFileEntry?
    @Published var showSidebar = true
    @Published var progress: FileOperationProgress?
    @Published var pendingConflict: PendingConflict?
    static var clipboard: FileClipboard?

    struct PendingConflict: Identifiable {
        let id = UUID()
        var intent: DropIntent
        var destination: String
        var names: [String]
    }

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
    private var flashToken = 0
    private var searchToken = 0
    private var folderSizes: [String: Int64] = [:]
    private var folderCounts: [String: Int] = [:]
    private var resolvedHome: String?

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

    func connectIfNeeded() {
        guard !session.isLocal else { return }
        if case .disconnected = session.state { session.start() }
    }

    func waitForConnection(timeout: TimeInterval = 30) async {
        guard !session.isLocal else { return }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if session.state.isConnected { return }
            if case .failed = session.state { return }
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    func loadPlaces() async {
        if session.isLocal {
            let volumes =
                FileManager.default.mountedVolumeURLs(
                    includingResourceValuesForKeys: [.volumeIsBrowsableKey],
                    options: [.skipHiddenVolumes]) ?? []
            let external = volumes.filter { $0.path != "/" }
            places = FilePlaces.localSections(volumes: external)
            return
        }
        let result = await session.runCommand(FilePlaces.homeDirectoryCommand(), timeout: 20)
        let home =
            (try? result.get())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "~"
        places = FilePlaces.remoteSections(home: home.isEmpty ? "~" : home)
    }

    func copySelection(operation: FileClipboardOperation) {
        let paths = selectedEntries.map(\.path)
        guard !paths.isEmpty else { return }
        Self.clipboard = FileClipboard(
            paths: paths, machineID: session.machine.id, operation: operation)
        flash(
            "\(operation == .copy ? "Copied" : "Cut") \(paths.count) item"
                + (paths.count == 1 ? "" : "s"))
    }

    func paste() async {
        guard let clipboard = Self.clipboard else { return }
        guard clipboard.machineID == session.machine.id else {
            errorMessage = "Copying between machines is not supported yet."
            return
        }
        guard let command = clipboard.command(intoDirectory: path) else { return }
        await run(command, reload: true)
        if clipboard.operation == .move { Self.clipboard = nil }
    }

    func showInfo() {
        infoTarget = selectedEntries.first
        guard let target = infoTarget, target.isDirectory else { return }
        Task { await measure(target) }
    }

    func infoSummary(for entry: RemoteFileEntry) -> FileInfoSummary {
        guard entry.isDirectory else { return FileInfoSummary(entry: entry) }
        return FileInfoSummary(entry: entry, sizeOverride: folderSummary(for: entry))
    }

    func setViewMode(_ mode: FileViewMode) {
        viewMode = mode
    }

    func toggleHidden() {
        showHidden.toggle()
    }

    func resolveHomeIfNeeded() async {
        guard !session.isLocal, path == "~" || path.isEmpty else { return }
        let result = await session.runCommand(FilePlaces.homeDirectoryCommand(), timeout: 20)
        guard case let .success(output) = result else { return }
        let home = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if home.hasPrefix("/") {
            resolvedHome = home
            path = home
        }
    }

    func load() async {
        await resolveHomeIfNeeded()
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
        let target = expandingHome(newPath)
        guard target != path else { return }
        if recordHistory {
            history.append(path)
            future.removeAll()
        }
        path = target
        entries = []
        selection = []
        anchor = nil
        searchResults = nil
        searchQuery = ""
        Task { await load() }
    }

    private func expandingHome(_ candidate: String) -> String {
        guard candidate == "~" || candidate.hasPrefix("~/") else { return candidate }
        guard let home = resolvedHome else { return candidate }
        if candidate == "~" { return home }
        return FileListing.join(parent: home, name: String(candidate.dropFirst(2)))
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
        let target =
            session.isLocal
            ? FileManager.default.homeDirectoryForCurrentUser.path
            : (places.first?.places.first?.path ?? "~")
        navigate(to: target)
    }

    func refresh() {
        Task { await load() }
    }

    func open(_ entry: RemoteFileEntry) {
        if entry.isDirectory || entry.kind == .symlink {
            navigate(to: entry.path)
            return
        }
        if session.isLocal {
            NSWorkspace.shared.open(URL(fileURLWithPath: entry.path))
            return
        }
        Task { await openRemote(entry) }
    }

    private func openRemote(_ entry: RemoteFileEntry) async {
        guard let connection = session.connectionRef else { return }
        let destination = PreviewCache.localURL(for: entry, machineID: session.machine.id)
        if FileManager.default.fileExists(atPath: destination.path) {
            NSWorkspace.shared.open(destination)
            return
        }
        statusMessage = "Opening \(entry.name)…"
        do {
            try await connection.download(remotePath: entry.path, to: destination)
            NSWorkspace.shared.open(destination)
            flash("Opened \(entry.name)")
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func openSelection() {
        guard let entry = selectedEntries.first else { return }
        open(entry)
    }

    func toggleQuickLook() {
        if quickLookPath != nil {
            quickLookPath = nil
        } else {
            quickLookPath = quickLookTarget
        }
    }

    private var quickLookTarget: String? {
        let ordered = visibleEntries.filter { selection.contains($0.path) }
        return ordered.first?.path ?? visibleEntries.first?.path
    }

    private func syncQuickLookToSelection() {
        guard quickLookPath != nil, let target = quickLookTarget, target != quickLookPath else {
            return
        }
        quickLookPath = target
    }

    func measure(_ entry: RemoteFileEntry) async {
        guard entry.isDirectory, folderSizes[entry.path] == nil else { return }
        folderSizes[entry.path] = -1
        if session.isLocal {
            let count = (try? FileManager.default.contentsOfDirectory(atPath: entry.path).count)
            folderCounts[entry.path] = count ?? 0
        }
        let result = await session.runCommand(
            FileOperations.directorySizeCommand(path: entry.path), timeout: 60)
        if case let .success(output) = result,
            let kilobytes = Int64(output.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            folderSizes[entry.path] = kilobytes
        } else {
            folderSizes[entry.path] = 0
        }
    }

    func folderSummary(for entry: RemoteFileEntry) -> String {
        guard let kilobytes = folderSizes[entry.path], kilobytes >= 0 else {
            return "Calculating size…"
        }
        var text = ByteFormatter.string(kilobytes * 1024)
        if let count = folderCounts[entry.path] {
            text += ", \(count) item\(count == 1 ? "" : "s")"
        }
        return text
    }

    func renameSelection() {
        guard let entry = selectedEntries.first else { return }
        beginRename(entry)
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
        guard RenameSelection.isValid(trimmed), trimmed != entry.name else { return }
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
        flash("Copied \(paths.count) path\(paths.count == 1 ? "" : "s")")
    }

    func flash(_ message: String) {
        statusMessage = message
        flashToken += 1
        let token = flashToken
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, token == flashToken else { return }
            statusMessage = nil
        }
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
        flash("Download finished")
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
        flash("Upload finished")
        await load()
    }

    func searchQueryChanged() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = nil
            searchToken += 1
            return
        }
        searchResults = entries.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        searchToken += 1
        let token = searchToken
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, token == searchToken, searchQuery == trimmed || !searchQuery.isEmpty
            else { return }
            await runDeepSearch(trimmed, token: token)
        }
    }

    private func runDeepSearch(_ query: String, token: Int) async {
        let shallow = entries.filter { $0.name.localizedCaseInsensitiveContains(query) }
        guard !session.isLocal else {
            let root = path
            let deep = await Task.detached(priority: .userInitiated) {
                MachineSession.searchLocalFiles(root: root, query: query)
            }.value
            guard token == searchToken else { return }
            var seen = Set(shallow.map { FilePathKey.canonical($0.path) })
            searchResults =
                shallow + deep.filter { seen.insert(FilePathKey.canonical($0.path)).inserted }
            return
        }
        let result = await session.runCommand(
            FileOperations.searchCommand(path: path, query: query), timeout: 45)
        guard token == searchToken, case let .success(output) = result else { return }
        var seen = Set(shallow.map(\.path))
        var combined = shallow
        for line in output.split(separator: "\n") {
            let full = String(line)
            guard !full.isEmpty, seen.insert(full).inserted else { continue }
            let isDirectory = entries.first { $0.path == full }?.isDirectory ?? false
            combined.append(
                RemoteFileEntry(
                    name: (full as NSString).lastPathComponent, path: full,
                    kind: isDirectory ? .directory : .file, sizeBytes: 0))
        }
        searchResults = combined
    }

    func runSearch() async {
        searchQueryChanged()
    }

    private func run(_ command: String, reload: Bool) async {
        let result = await session.runCommand(command, timeout: 120)
        if case let .failure(failure) = result {
            errorMessage = failure.localizedDescription
        }
        if reload { await load() }
    }

    func dragPayload() -> MachineItemsPayload {
        MachineItemsPayload(
            machineID: session.machine.id, paths: selectedEntries.map(\.path),
            isLocal: session.isLocal)
    }

    func handleDrop(
        providers: [NSItemProvider], destination: String, optionHeld: Bool
    ) async {
        var payload: MachineItemsPayload?
        var localPaths: [String] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(MachineItemsPayload.typeIdentifier) {
                if let data = await provider.loadDataSafely(
                    forTypeIdentifier: MachineItemsPayload.typeIdentifier)
                {
                    payload = MachineItemsPayload.decode(data)
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                if let data = await provider.loadDataSafely(
                    forTypeIdentifier: UTType.fileURL.identifier),
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                {
                    localPaths.append(url.path)
                }
            }
        }
        guard
            let intent = DropResolver.intent(
                payload: payload, fileURLPaths: localPaths,
                destinationMachine: session.machine.id, optionHeld: optionHeld)
        else { return }
        await perform(intent: intent, destination: destination)
    }

    private func destinationEntries(_ destination: String) async -> [RemoteFileEntry] {
        if destination == path { return entries }
        if case let .success(items) = await session.listFiles(path: destination) { return items }
        return []
    }

    func perform(intent: DropIntent, destination: String) async {
        guard DropResolver.isDropAllowed(paths: intent.paths, destination: destination) else {
            return
        }
        let names = intent.paths.map { ($0 as NSString).lastPathComponent }
        let existing = await destinationEntries(destination)
        let clashes = NameConflicts.conflicting(names: names, existing: existing)
        if !clashes.isEmpty {
            pendingConflict = PendingConflict(
                intent: intent, destination: destination, names: clashes)
            return
        }
        await commit(intent: intent, destination: destination, resolutions: [:])
    }

    func commit(
        intent: DropIntent, destination: String,
        resolutions: [String: NameConflictResolution]
    ) async {
        switch intent {
        case .moveWithinMachine, .copyWithinMachine:
            let existing = await destinationEntries(destination)
            guard
                let command = NameConflicts.command(
                    intent: intent, destination: destination, resolutions: resolutions,
                    existing: existing)
            else { return }
            progress = FileOperationProgress(
                title: intent.isMove ? "Moving" : "Copying", total: intent.paths.count)
            await run(command, reload: true)
            progress = nil
        case let .uploadLocalFiles(paths):
            await uploadPaths(paths.map { URL(fileURLWithPath: $0) }, into: destination)
        case let .transferBetweenMachines(from, paths):
            await transfer(paths: paths, fromMachine: from, into: destination)
        }
    }

    private func transfer(paths: [String], fromMachine: UUID, into destination: String) async {
        guard let source = MachinesModel.shared.sessions[fromMachine] else { return }
        progress = FileOperationProgress(title: "Transferring", total: paths.count)
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        var completed = 0
        var failures: [String] = []
        for path in paths {
            let name = (path as NSString).lastPathComponent
            let local = staging.appendingPathComponent(name)
            do {
                if source.isLocal {
                    try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: local)
                } else if let connection = source.connectionRef {
                    try await connection.download(remotePath: path, to: local)
                } else {
                    throw TransferFailure.noConnection(source.machine.name)
                }
                if session.isLocal {
                    try FileManager.default.moveItem(
                        at: local,
                        to: URL(fileURLWithPath: FileListing.join(parent: destination, name: name)))
                } else if let connection = session.connectionRef {
                    try await connection.upload(
                        localURL: local,
                        toRemotePath: FileListing.join(parent: destination, name: name))
                } else {
                    throw TransferFailure.noConnection(session.machine.name)
                }
                completed += 1
            } catch {
                failures.append("\(name): \(error.localizedDescription)")
            }
            progress = FileOperationProgress(
                title: "Transferring", completed: completed, total: paths.count)
        }
        try? FileManager.default.removeItem(at: staging)
        progress = nil
        if failures.isEmpty {
            flash("Transferred \(completed) item\(completed == 1 ? "" : "s")")
        } else {
            errorMessage =
                failures.count == 1
                ? failures[0]
                : "\(failures.count) of \(paths.count) items failed. \(failures[0])"
        }
        await load()
    }

    enum TransferFailure: LocalizedError {
        case noConnection(String)

        var errorDescription: String? {
            switch self {
            case let .noConnection(name): return "\(name) is not connected."
            }
        }
    }

    private func uploadPaths(_ urls: [URL], into destination: String) async {
        guard !urls.isEmpty else { return }
        progress = FileOperationProgress(title: "Uploading", total: urls.count)
        if session.isLocal {
            for url in urls {
                let target = FileListing.join(
                    parent: destination, name: url.lastPathComponent)
                try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: target))
            }
        } else if let connection = session.connectionRef {
            var completed = 0
            for url in urls {
                let target = FileListing.join(
                    parent: destination, name: url.lastPathComponent)
                try? await connection.upload(localURL: url, toRemotePath: target)
                completed += 1
                progress = FileOperationProgress(
                    title: "Uploading", completed: completed, total: urls.count)
            }
        }
        progress = nil
        await load()
    }

    func moveSelection(into destination: String) async {
        let paths = selectedEntries.map(\.path)
        guard !paths.isEmpty else { return }
        await perform(intent: .moveWithinMachine(paths), destination: destination)
    }

    func dragProvider(for entry: RemoteFileEntry) -> NSItemProvider {
        let provider = itemProvider(for: entry)
        if let data = dragPayload().encoded() {
            provider.registerDataRepresentation(
                forTypeIdentifier: MachineItemsPayload.typeIdentifier, visibility: .ownProcess
            ) { completion in
                completion(data, nil)
                return nil
            }
        }
        return provider
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

extension DropIntent {
    var isMove: Bool {
        if case .moveWithinMachine = self { return true }
        return false
    }
}

extension NSItemProvider {
    func loadDataSafely(forTypeIdentifier identifier: String) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = loadDataRepresentation(forTypeIdentifier: identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
