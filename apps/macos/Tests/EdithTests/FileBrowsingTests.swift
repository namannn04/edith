import Foundation
import Testing

@testable import EdithKit

@Suite struct FileSortingTests {
    private let entries = [
        RemoteFileEntry(
            name: "readme.md", path: "/a/readme.md", kind: .file, sizeBytes: 300,
            modified: Date(timeIntervalSince1970: 300)),
        RemoteFileEntry(
            name: "Apple", path: "/a/Apple", kind: .directory, sizeBytes: 4096,
            modified: Date(timeIntervalSince1970: 100)),
        RemoteFileEntry(
            name: "banana.txt", path: "/a/banana.txt", kind: .file, sizeBytes: 100,
            modified: Date(timeIntervalSince1970: 200)),
        RemoteFileEntry(
            name: "zebra", path: "/a/zebra", kind: .directory, sizeBytes: 4096,
            modified: Date(timeIntervalSince1970: 400)),
    ]

    @Test func foldersComeFirstRegardlessOfKey() {
        for key in FileSortKey.allCases {
            for ascending in [true, false] {
                let sorted = FileSorting.sort(entries, by: key, ascending: ascending)
                let leadingAreFolders = sorted.prefix(2).allSatisfy { $0.isDirectory }
                let trailingAreFiles = sorted.suffix(2).allSatisfy { !$0.isDirectory }
                #expect(leadingAreFolders)
                #expect(trailingAreFiles)
            }
        }
    }

    @Test func sortsByNameCaseInsensitively() {
        let sorted = FileSorting.sort(entries, by: .name, ascending: true)
        #expect(sorted.map(\.name) == ["Apple", "zebra", "banana.txt", "readme.md"])
    }

    @Test func sortsBySizeAndDate() {
        let bySize = FileSorting.sort(entries, by: .size, ascending: true)
        #expect(bySize.suffix(2).map(\.name) == ["banana.txt", "readme.md"])
        let byDate = FileSorting.sort(entries, by: .modified, ascending: false)
        #expect(byDate.suffix(2).map(\.name) == ["readme.md", "banana.txt"])
    }

    @Test func descendingReversesWithinGroups() {
        let sorted = FileSorting.sort(entries, by: .name, ascending: false)
        #expect(sorted.map(\.name) == ["zebra", "Apple", "readme.md", "banana.txt"])
    }

    @Test func sortIsStableForEqualKeys() {
        let same = (1...5).map {
            RemoteFileEntry(
                name: "file\($0)", path: "/a/file\($0)", kind: .file, sizeBytes: 10,
                modified: Date(timeIntervalSince1970: 0))
        }
        #expect(
            FileSorting.sort(same, by: .size, ascending: true).map(\.name)
                == ["file1", "file2", "file3", "file4", "file5"])
    }

    @Test func describesKinds() {
        #expect(entries[1].kindDescription == "Folder")
        #expect(entries[0].kindDescription == "MD file")
        #expect(
            RemoteFileEntry(name: "link", path: "/l", kind: .symlink, sizeBytes: 0)
                .kindDescription == "Alias")
        #expect(
            RemoteFileEntry(name: "binary", path: "/b", kind: .file, sizeBytes: 0)
                .kindDescription == "Document")
    }
}

@Suite struct FileSelectionMathTests {
    private let entries = (1...5).map {
        RemoteFileEntry(name: "f\($0)", path: "/p/f\($0)", kind: .file, sizeBytes: 1)
    }

    @Test func rangeSelectionSpansBothDirections() {
        #expect(
            FileSelectionMath.rangeSelection(in: entries, from: "/p/f2", to: "/p/f4")
                == ["/p/f2", "/p/f3", "/p/f4"])
        #expect(
            FileSelectionMath.rangeSelection(in: entries, from: "/p/f4", to: "/p/f2")
                == ["/p/f2", "/p/f3", "/p/f4"])
    }

    @Test func rangeWithoutAnchorSelectsOnlyTarget() {
        #expect(
            FileSelectionMath.rangeSelection(in: entries, from: nil, to: "/p/f3") == ["/p/f3"])
    }

    @Test func toggleAddsAndRemoves() {
        let once = FileSelectionMath.toggled([], path: "/p/f1")
        #expect(once == ["/p/f1"])
        #expect(FileSelectionMath.toggled(once, path: "/p/f1").isEmpty)
    }

    @Test func typeSelectFindsAndCyclesMatches() {
        let items = [
            RemoteFileEntry(name: "alpha", path: "/a", kind: .file, sizeBytes: 0),
            RemoteFileEntry(name: "Apple", path: "/b", kind: .file, sizeBytes: 0),
            RemoteFileEntry(name: "beta", path: "/c", kind: .file, sizeBytes: 0),
        ]
        #expect(FileSelectionMath.typeSelectMatch(in: items, prefix: "a", after: nil) == "/a")
        #expect(FileSelectionMath.typeSelectMatch(in: items, prefix: "a", after: "/a") == "/b")
        #expect(FileSelectionMath.typeSelectMatch(in: items, prefix: "a", after: "/b") == "/a")
        #expect(FileSelectionMath.typeSelectMatch(in: items, prefix: "be", after: nil) == "/c")
        #expect(FileSelectionMath.typeSelectMatch(in: items, prefix: "z", after: nil) == nil)
    }
}

@Suite struct FileOperationsTests {
    private let entries = [
        RemoteFileEntry(name: "untitled folder", path: "/a", kind: .directory, sizeBytes: 0),
        RemoteFileEntry(name: "notes.txt", path: "/b", kind: .file, sizeBytes: 0),
    ]

    @Test func newFolderNameAvoidsCollisions() {
        #expect(FileOperations.newFolderName(existing: []) == "untitled folder")
        #expect(FileOperations.newFolderName(existing: entries) == "untitled folder 2")
    }

    @Test func duplicateNameKeepsExtension() {
        #expect(
            FileOperations.duplicateName(of: "notes.txt", existing: entries) == "notes copy.txt")
        #expect(FileOperations.duplicateName(of: "README", existing: []) == "README copy")
    }

    @Test func duplicateNameIncrementsWhenTaken() {
        let taken = [
            RemoteFileEntry(name: "a copy.txt", path: "/x", kind: .file, sizeBytes: 0)
        ]
        #expect(FileOperations.duplicateName(of: "a.txt", existing: taken) == "a copy 2.txt")
    }

    @Test func trashCommandFollowsFreedesktopLayout() {
        let command = FileOperations.trashCommand(paths: ["/home/p/a b.txt"])
        #expect(command.contains(".local/share/Trash/files"))
        #expect(command.contains(".local/share/Trash/info"))
        #expect(command.contains("trashinfo"))
        #expect(command.contains("'/home/p/a b.txt'"))
        #expect(!command.contains("rm -rf"))
    }

    @Test func destructiveCommandsQuotePaths() {
        #expect(
            FileOperations.deleteCommand(paths: ["/a b", "/c"]) == "rm -rf '/a b' /c")
        #expect(
            FileOperations.moveCommand(paths: ["/a b"], toDirectory: "/dest dir")
                == "mv '/a b' '/dest dir'")
        #expect(
            FileOperations.copyCommand(paths: ["/a"], toDirectory: "/d") == "cp -a /a /d")
    }

    @Test func renameRefusesToClobber() {
        let command = FileOperations.renameCommand(path: "/a/x", to: "/a/y")
        #expect(command == "mv -n /a/x /a/y")
    }

    @Test func searchAndSpaceCommandsAreQuoted() {
        let search = FileOperations.searchCommand(path: "/my dir", query: "note")
        #expect(search.contains("'/my dir'"))
        #expect(search.contains("'*note*'"))
        #expect(search.contains("head -300"))
        #expect(FileOperations.freeSpaceCommand(path: "/my dir").contains("'/my dir'"))
        #expect(FileOperations.directorySizeCommand(path: "/x").contains("du -sk"))
    }
}

@Suite struct FileViewModeTests {
    @Test func viewModesCarryTitlesAndSymbols() {
        for mode in FileViewMode.allCases {
            #expect(!mode.title.isEmpty)
            #expect(!mode.symbol.isEmpty)
        }
        #expect(FileViewMode.allCases.count == 2)
    }

    @Test func sortKeysAreCodableAndTitled() throws {
        for key in FileSortKey.allCases {
            #expect(!key.title.isEmpty)
            let data = try JSONEncoder().encode(key)
            let decoded = try JSONDecoder().decode(FileSortKey.self, from: data)
            #expect(decoded == key)
        }
    }
}

@Suite struct FilePlacesTests {
    @Test func localSectionsCoverFavoritesAndVolumes() {
        let home = URL(fileURLWithPath: "/Users/tester")
        let sections = FilePlaces.localSections(
            home: home, volumes: [URL(fileURLWithPath: "/Volumes/Backup")])
        #expect(sections.map(\.title) == ["Favorites", "Locations"])
        let favorites = sections[0].places
        #expect(favorites.first?.path == "/Users/tester")
        #expect(favorites.contains { $0.path == "/Users/tester/Downloads" })
        #expect(sections[1].places.contains { $0.name == "Backup" })
        #expect(sections[1].places.first?.path == "/")
    }

    @Test func listingQuotesPathsSoTildeMustBeResolvedFirst() {
        #expect(FileListing.command(path: "~", showHidden: true).contains("'~'"))
        #expect(FilePlaces.homeDirectoryCommand() == "echo $HOME")
    }

    @Test func remoteSectionsUseTheResolvedHome() {
        let sections = FilePlaces.remoteSections(home: "/home/pulkit")
        #expect(sections[0].places.first?.path == "/home/pulkit")
        #expect(sections[0].places.contains { $0.path == "/home/pulkit/Documents" })
        #expect(sections[1].places.contains { $0.path == "/var/log" })
    }
}

@Suite struct FileClipboardTests {
    @Test func copyAndMoveProduceTheRightCommand() {
        let machine = UUID()
        let copy = FileClipboard(paths: ["/a/x", "/a/y"], machineID: machine, operation: .copy)
        #expect(copy.command(intoDirectory: "/dest") == "cp -a /a/x /a/y /dest")
        let move = FileClipboard(paths: ["/a x"], machineID: machine, operation: .move)
        #expect(move.command(intoDirectory: "/dest dir") == "mv '/a x' '/dest dir'")
    }

    @Test func emptyClipboardProducesNoCommand() {
        let clipboard = FileClipboard(paths: [], machineID: UUID(), operation: .copy)
        #expect(clipboard.command(intoDirectory: "/dest") == nil)
    }
}

@Suite struct FileInfoSummaryTests {
    @Test func describesOctalPermissions() {
        #expect(FileInfoSummary.describe(mode: "755") == "755  ·  rwxr-xr-x")
        #expect(FileInfoSummary.describe(mode: "644") == "644  ·  rw-r--r--")
        #expect(FileInfoSummary.describe(mode: "") == "Unknown")
        #expect(FileInfoSummary.describe(mode: "drwxr-xr-x") == "drwxr-xr-x")
    }

    @Test func summarizesAnEntry() {
        let entry = RemoteFileEntry(
            name: "notes.txt", path: "/home/p/notes.txt", kind: .file, sizeBytes: 2048,
            modified: Date(timeIntervalSince1970: 1_754_000_000), mode: "644")
        let summary = FileInfoSummary(entry: entry)
        #expect(summary.kind == "TXT file")
        #expect(summary.size == "2.0 KB")
        #expect(summary.permissions.hasPrefix("644"))
    }

    @Test func foldersCanOverrideSize() {
        let entry = RemoteFileEntry(
            name: "src", path: "/home/p/src", kind: .directory, sizeBytes: 4096)
        #expect(FileInfoSummary(entry: entry).size == "—")
        #expect(FileInfoSummary(entry: entry, sizeOverride: "1.2 GB").size == "1.2 GB")
    }
}

@Suite struct RenameSelectionTests {
    @Test func selectsBaseNameWithoutExtension() {
        let name = "report.final.pdf"
        let range = RenameSelection.baseNameRange(of: name)
        #expect(range.map { String(name[$0]) } == "report.final")
        #expect(RenameSelection.baseNameRange(of: "README") == nil)
    }

    @Test func rejectsInvalidNames() {
        #expect(RenameSelection.isValid("notes.txt"))
        #expect(!RenameSelection.isValid(""))
        #expect(!RenameSelection.isValid("   "))
        #expect(!RenameSelection.isValid("a/b"))
        #expect(!RenameSelection.isValid(".."))
    }
}
