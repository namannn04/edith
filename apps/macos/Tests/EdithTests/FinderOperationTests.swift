import AppKit
import EdithKit
import Foundation
import Testing

@testable import Edith

@MainActor
private func sandbox() throws -> (model: FinderModel, root: URL) {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("edith-finder-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let root = URL(fileURLWithPath: (base.path as NSString).resolvingSymlinksInPath)
    let session = MachinesModel.shared.session(for: MachinesModel.localMachineID)
    return (FinderModel(session: session, path: root.path), root)
}

private func write(_ name: String, into root: URL, contents: String = "x") throws {
    try contents.write(
        to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
}

private func resolved(_ path: String) -> String {
    (path as NSString).resolvingSymlinksInPath
}

private func exists(_ name: String, in root: URL) -> Bool {
    FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path)
}

@Suite(.serialized) @MainActor struct FinderRenameTests {
    @Test func renamingAFileMovesItOnDisk() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("before.txt", into: root)
        await model.load()

        guard let entry = model.entries.first(where: { $0.name == "before.txt" }) else {
            Issue.record("listing did not include the file")
            return
        }
        model.beginRename(entry)
        #expect(model.renaming == entry.path)
        model.renameText = "after.txt"
        await model.commitRename()

        #expect(exists("after.txt", in: root))
        #expect(!exists("before.txt", in: root))
        #expect(model.renaming == nil)
    }

    @Test func renamingOntoAnExistingNameDoesNotDestroyIt() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("keep.txt", into: root, contents: "important")
        try write("other.txt", into: root, contents: "other")
        await model.load()

        guard let entry = model.entries.first(where: { $0.name == "other.txt" }) else { return }
        model.beginRename(entry)
        model.renameText = "keep.txt"
        await model.commitRename()

        let kept = try String(contentsOf: root.appendingPathComponent("keep.txt"), encoding: .utf8)
        #expect(kept == "important")
        #expect(exists("other.txt", in: root))
    }

    @Test func anEmptyOrUnchangedNameIsANoOp() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("file.txt", into: root)
        await model.load()

        guard let entry = model.entries.first else { return }
        model.beginRename(entry)
        model.renameText = "   "
        await model.commitRename()
        #expect(exists("file.txt", in: root))

        model.beginRename(entry)
        model.renameText = "file.txt"
        await model.commitRename()
        #expect(exists("file.txt", in: root))
    }
}

@Suite(.serialized) @MainActor struct FinderCreateAndDeleteTests {
    @Test func newFolderCreatesItAndOpensTheRenameField() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        await model.load()
        await model.newFolder()

        #expect(exists("untitled folder", in: root))
        #expect(model.renaming != nil)
        #expect(model.renameText == "untitled folder")
    }

    @Test func asecondNewFolderDoesNotCollide() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        await model.load()
        await model.newFolder()
        await model.newFolder()

        #expect(exists("untitled folder", in: root))
        #expect(exists("untitled folder 2", in: root))
    }

    @Test func duplicateMakesACopyBesideTheOriginal() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("notes.txt", into: root, contents: "body")
        await model.load()
        model.selection = Set(model.entries.filter { $0.name == "notes.txt" }.map(\.path))
        await model.duplicateSelection()

        #expect(exists("notes.txt", in: root))
        #expect(exists("notes copy.txt", in: root))
    }

    @Test func deletingImmediatelyRemovesTheFile() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("gone.txt", into: root)
        await model.load()
        model.selection = Set(model.entries.filter { $0.name == "gone.txt" }.map(\.path))
        await model.trashSelection(permanently: true)

        #expect(!exists("gone.txt", in: root))
        #expect(model.selection.isEmpty)
    }
}

@Suite(.serialized) @MainActor struct FinderNavigationTests {
    @Test func openingAFolderNavigatesIntoIt() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let inner = root.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try write("deep.txt", into: inner)
        await model.load()

        guard let folder = model.entries.first(where: { $0.name == "inner" }) else { return }
        model.open(folder)
        try await Task.sleep(for: .milliseconds(400))

        #expect(resolved(model.path) == resolved(inner.path))
        #expect(model.entries.contains { $0.name == "deep.txt" })
    }

    @Test func backAndForwardWalkTheHistory() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let inner = root.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        await model.load()

        model.navigate(to: inner.path)
        try await Task.sleep(for: .milliseconds(300))
        #expect(model.canGoBack)

        model.goBack()
        try await Task.sleep(for: .milliseconds(300))
        #expect(resolved(model.path) == resolved(root.path))
        #expect(model.canGoForward)

        model.goForward()
        try await Task.sleep(for: .milliseconds(300))
        #expect(resolved(model.path) == resolved(inner.path))
    }

    @Test func navigatingClearsTheOldListingSoNoStaleRowsShow() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("outer.txt", into: root)
        let inner = root.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        await model.load()
        #expect(model.entries.contains { $0.name == "outer.txt" })

        model.navigate(to: inner.path)
        #expect(model.entries.isEmpty)
    }
}

@Suite(.serialized) @MainActor struct FinderClipboardTests {
    @Test func cutThenPasteMovesTheFile() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("moving.txt", into: root)
        let inner = root.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        await model.load()

        model.selection = Set(model.entries.filter { $0.name == "moving.txt" }.map(\.path))
        model.copySelection(operation: .move)
        model.navigate(to: inner.path)
        try await Task.sleep(for: .milliseconds(300))
        await model.paste()

        #expect(exists("inner/moving.txt", in: root))
        #expect(!exists("moving.txt", in: root))
    }

    @Test func copyThenPasteLeavesTheOriginal() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("copying.txt", into: root)
        let inner = root.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        await model.load()

        model.selection = Set(model.entries.filter { $0.name == "copying.txt" }.map(\.path))
        model.copySelection(operation: .copy)
        model.navigate(to: inner.path)
        try await Task.sleep(for: .milliseconds(300))
        await model.paste()

        #expect(exists("copying.txt", in: root))
        #expect(exists("inner/copying.txt", in: root))
    }

    @Test func draggingOntoAFolderMovesIntoIt() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("dragged.txt", into: root)
        let inner = root.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        await model.load()

        let source = model.entries.first { $0.name == "dragged.txt" }?.path ?? ""
        await model.perform(
            intent: .moveWithinMachine([source]), destination: inner.path)
        try await Task.sleep(for: .milliseconds(300))

        #expect(exists("inner/dragged.txt", in: root))
        #expect(!exists("dragged.txt", in: root))
    }
}

@Suite(.serialized) @MainActor struct FinderSearchTests {
    @Test func searchFindsMatchesInSubfoldersNotJustTheCurrentOne() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let inner = root.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try write("needle.txt", into: inner)
        try write("haystack.txt", into: root)
        await model.load()

        model.searchQuery = "needle"
        model.searchQueryChanged()
        try await Task.sleep(for: .milliseconds(900))

        #expect(model.searchResults?.contains { $0.name == "needle.txt" } == true)
    }

    @Test func clearingTheSearchRestoresTheListing() async throws {
        let (model, root) = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("alpha.txt", into: root)
        try write("beta.txt", into: root)
        await model.load()

        model.searchQuery = "alpha"
        model.searchQueryChanged()
        try await Task.sleep(for: .milliseconds(400))
        #expect(model.visibleEntries.count == 1)

        model.searchQuery = ""
        model.searchQueryChanged()
        try await Task.sleep(for: .milliseconds(400))
        #expect(model.searchResults == nil)
        #expect(model.visibleEntries.count == 2)
    }
}
