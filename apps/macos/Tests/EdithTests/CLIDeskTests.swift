import ArgumentParser
import Foundation
import Testing

@testable import EdithCLI
@testable import EdithKit

@Suite struct CLIAppActionTests {
    @Test func everyActionIsReachableAsItsOwnSubcommand() throws {
        for action in AppActions.all {
            let parsed = try EdRoot.parseAsRoot(["app", action.name])
            #expect(CommandCrawler.name(of: type(of: parsed)) == action.name)
        }
    }

    @Test func theActionListNamesEveryActionTheCommandGroupHas() async {
        let result = await CLIProbe.run(["app", "actions", "--json"])
        #expect(result.code == 0)
        let rows = result.array as? [[String: Any]] ?? []
        #expect(rows.compactMap { $0["action"] as? String } == AppActions.all.map(\.name))
        for row in rows {
            #expect(Set(row.keys) == ["action", "summary", "needs", "available"])
            #expect(row["available"] as? Bool == false)
        }
    }

    @Test func anActionThatNeedsTheMenuBarSaysSoWhenItIsClosed() async {
        for name in ["clean-keys", "test-notification", "open"] {
            let result = await CLIProbe.run(["app", name])
            #expect(result.code == ExitCodes.unavailable, "\(name) exited \(result.code)")
            #expect(result.stderr.contains("menu bar app"))
            #expect(result.stdout.isEmpty)
        }
    }

    @Test func anActionThatNeedsTheMainWindowSaysSoWhenItIsClosed() async {
        for name in ["quit", "check-updates"] {
            let result = await CLIProbe.run(["app", name])
            #expect(result.code == ExitCodes.unavailable, "\(name) exited \(result.code)")
            #expect(result.stderr.contains("main window"))
        }
    }

    @Test func eachActionPostsItsOwnNotificationAndNoOther() async throws {
        let expected: [String: Notification.Name] = [
            "clean-keys": IPC.Name.requestKeyboardClean,
            "test-notification": IPC.Name.requestTestNotification,
            "open": IPC.Name.openPanel,
        ]
        for (name, notification) in expected {
            try await CLIProbe.inWorld { world in
                world.helperRunning(true)
                let result = await CLIProbe.capture(["app", name])
                #expect(result.code == 0, "\(name) exited \(result.code)")
                #expect(world.postedNames() == [notification.rawValue])
            }
        }
    }

    @Test func quitAsksTheMainAppRatherThanTheMenuBar() async throws {
        try await CLIProbe.inWorld { world in
            CLIEnvironment.isMainAppRunning = { true }
            let result = await CLIProbe.capture(["app", "quit", "--json"])
            #expect(result.code == 0)
            #expect(world.postedNames() == [IPC.Name.quitMainApp.rawValue])
            #expect(result.object?["action"] as? String == "quit")
        }
    }

    @Test func anUpdateCheckWaitsForTheAppToFinishAndReportsTheOutcome() async throws {
        try await CLIProbe.inWorld { world in
            CLIEnvironment.isMainAppRunning = { true }
            world.answers { _ in ["outcome": "updateFound", "version": "2.1.0"] }
            let result = await CLIProbe.capture(["app", "check-updates", "--json"])
            #expect(result.code == 0)
            #expect(result.object?["outcome"] as? String == "updateFound")
            #expect(result.object?["version"] as? String == "2.1.0")
            #expect(result.object?["finished"] as? Bool == true)
            #expect(world.postedNames() == [IPC.Name.requestUpdateCheck.rawValue])
        }
    }

    @Test func anUpdateCheckThatGoesQuietIsDiagnosedRatherThanCallingItDone() async throws {
        try await CLIProbe.inWorld { world in
            CLIEnvironment.isMainAppRunning = { true }
            world.helperRunning(true)
            world.answers { _ in nil }
            let result = await CLIProbe.capture(["app", "check-updates"])
            #expect(result.code == ExitCodes.unavailable)
            #expect(result.stderr.contains("did not answer"))
        }
    }

    @Test func noWaitReturnsWithoutClaimingTheCheckFinished() async throws {
        try await CLIProbe.inWorld { world in
            CLIEnvironment.isMainAppRunning = { true }
            world.answers { _ in nil }
            let result = await CLIProbe.capture(["app", "check-updates", "--no-wait", "--json"])
            #expect(result.code == 0)
            #expect(result.object?["finished"] as? Bool == false)
        }
    }

    @Test func theUpdateLogIsReadWithoutTheAppRunning() async {
        let result = await CLIProbe.run(["app", "updates", "--json"])
        #expect(result.code == 0)
        #expect(result.array != nil)
    }

    @Test func anUnknownActionIsNotFound() {
        #expect(throws: CLIFailure.self) { try AppActions.named("self-destruct") }
    }
}

@Suite struct CLIClipboardTests {
    static func seed(_ world: CLIWorld, count: Int) throws {
        var entries: [ClipboardEntry] = []
        for index in 0..<count {
            let text = "entry number \(index)"
            let data = Data(text.utf8)
            let sha = ClipboardRepository.sha256Hex(data)
            try ClipboardRepository.writeBlob(data, sha256: sha, ext: "txt")
            entries.append(
                ClipboardEntry(
                    sha256: sha, types: ["public.utf8-plain-text"], ext: "txt",
                    sourceApp: "Tester", sourceBundleID: "test.app",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
                    size: data.count, preview: text, pinned: index == 0))
        }
        try ClipboardRepository.saveEntries(entries)
    }

    @Test func anEmptyHistoryIsUnavailableRatherThanACrash() async {
        let result = await CLIProbe.run(["clipboard", "get", "1"])
        #expect(result.code == ExitCodes.unavailable)
        #expect(result.stderr.contains("empty"))
    }

    @Test func listingIsNewestFirstAndNumberedFromOne() async throws {
        try await CLIProbe.inWorld { world in
            try Self.seed(world, count: 3)
            let result = await CLIProbe.capture(["clipboard", "ls", "--json"])
            #expect(result.code == 0)
            let rows = result.array as? [[String: Any]] ?? []
            #expect(rows.count == 3)
            #expect(rows.first?["index"] as? Int == 1)
            #expect(rows.first?["preview"] as? String == "entry number 2")
            #expect(rows.last?["preview"] as? String == "entry number 0")
        }
    }

    @Test func gettingAnEntryPrintsItsTextAndNothingElse() async throws {
        try await CLIProbe.inWorld { world in
            try Self.seed(world, count: 2)
            let result = await CLIProbe.capture(["clipboard", "get", "2"])
            #expect(result.code == 0)
            #expect(result.stdout == "entry number 0\n")
        }
    }

    @Test func anIndexOutsideTheHistoryIsNotFound() async throws {
        try await CLIProbe.inWorld { world in
            try Self.seed(world, count: 2)
            for index in ["0", "3", "99"] {
                let result = await CLIProbe.capture(["clipboard", "get", index])
                #expect(result.code == ExitCodes.notFound, "index \(index) exited \(result.code)")
                #expect(result.stderr.contains("numbered from 1"))
            }
        }
    }

    @Test func removingAnEntryLeavesTheRest() async throws {
        try await CLIProbe.inWorld { world in
            try Self.seed(world, count: 3)
            let removed = await CLIProbe.capture(["clipboard", "rm", "1", "--json"])
            #expect(removed.object?["remaining"] as? Int == 2)
            let after = await CLIProbe.capture(["clipboard", "ls", "--json"])
            #expect((after.array as? [Any])?.count == 2)
            #expect(world.postedNames().contains(IPC.Name.clipboardChanged.rawValue))
        }
    }

    @Test func clearingCanKeepThePinnedOnes() async throws {
        try await CLIProbe.inWorld { world in
            try Self.seed(world, count: 3)
            let result = await CLIProbe.capture([
                "clipboard", "clear", "--keep-pinned", "--json",
            ])
            #expect(result.object?["remaining"] as? Int == 1)
            let after = await CLIProbe.capture(["clipboard", "ls", "--json"])
            let rows = after.array as? [[String: Any]] ?? []
            #expect(rows.count == 1)
            #expect(rows.first?["pinned"] as? Bool == true)
        }
    }

    @Test func clearingWithoutKeepingAnythingEmptiesIt() async throws {
        try await CLIProbe.inWorld { world in
            try Self.seed(world, count: 3)
            let result = await CLIProbe.capture(["clipboard", "clear", "--json"])
            #expect(result.object?["removed"] as? Int == 3)
            #expect(result.object?["remaining"] as? Int == 0)
        }
    }

    @Test func aPreviewWithNewlinesNeverBreaksTheTable() async throws {
        try await CLIProbe.inWorld { world in
            let data = Data("first line\nsecond line".utf8)
            let sha = ClipboardRepository.sha256Hex(data)
            try ClipboardRepository.writeBlob(data, sha256: sha, ext: "txt")
            try ClipboardRepository.saveEntries([
                ClipboardEntry(
                    sha256: sha, types: ["public.utf8-plain-text"], ext: "txt",
                    sourceApp: nil, sourceBundleID: nil, size: data.count,
                    preview: "first line\nsecond line")
            ])
            let result = await CLIProbe.capture(["clipboard", "ls"])
            #expect(result.stdoutLines.count == 2)
        }
    }
}

@Suite struct CLIColorTests {
    static func seed(_ world: CLIWorld, count: Int) {
        let swatches = (0..<count).map { index in
            ColorSwatch(
                red: Double(index) / 10, green: 0.5, blue: 1, profile: .sRGB,
                pickedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)))
        }
        guard let data = try? JSONEncoder().encode(swatches) else { return }
        world.shared.set(data, forKey: "colorPickerHistory")
    }

    @Test func anEmptyHistoryListsNothingRatherThanFailing() async {
        let result = await CLIProbe.run(["color", "ls", "--json"])
        #expect(result.code == 0)
        #expect((result.array as? [Any])?.isEmpty == true)
    }

    @Test func everySwatchCarriesEveryFormat() async throws {
        try await CLIProbe.inWorld { world in
            Self.seed(world, count: 2)
            let result = await CLIProbe.capture(["color", "ls", "--json"])
            let rows = result.array as? [[String: Any]] ?? []
            #expect(rows.count == 2)
            for row in rows {
                #expect(Set(row.keys) == ["hex", "rgb", "hsl", "profile", "pickedAt"])
                #expect((row["hex"] as? String)?.hasPrefix("#") == true)
            }
        }
    }

    @Test func oneFormatPrintsOneColumnOfValues() async throws {
        try await CLIProbe.inWorld { world in
            Self.seed(world, count: 2)
            let result = await CLIProbe.capture(["color", "ls", "--format", "hex"])
            #expect(result.code == 0)
            #expect(result.stdoutLines.count == 2)
            #expect(result.stdoutLines.allSatisfy { $0.hasPrefix("#") })
        }
    }

    @Test func anUnknownFormatIsNotFoundAndListsTheRealOnes() async {
        let result = await CLIProbe.run(["color", "ls", "--format", "cmyk"])
        #expect(result.code == ExitCodes.notFound)
        #expect(result.stderr.contains("formats:"))
    }

    @Test func clearingForgetsEverySwatch() async throws {
        try await CLIProbe.inWorld { world in
            Self.seed(world, count: 4)
            let result = await CLIProbe.capture(["color", "clear", "--json"])
            #expect(result.object?["removed"] as? Int == 4)
            #expect(ColorHistoryStore.load(from: world.shared).isEmpty)
        }
    }

    @Test func colourIsSpeltBothWays() throws {
        for name in ["color", "colour"] {
            let parsed = try EdRoot.parseAsRoot([name, "ls"])
            #expect(CommandCrawler.name(of: type(of: parsed)) == "ls")
        }
    }
}

@Suite struct CLIShelfTests {
    static func seed(_ world: CLIWorld, names: [String]) throws {
        try FileManager.default.createDirectory(
            at: ShelfIndex.root, withIntermediateDirectories: true)
        var items: [ShelfItem] = []
        for (index, name) in names.enumerated() {
            try Data("contents of \(name)".utf8).write(
                to: ShelfIndex.root.appendingPathComponent(name))
            items.append(
                ShelfItem(
                    id: UUID(), name: name,
                    addedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index))))
        }
        ShelfIndex.save(items)
    }

    @Test func anEmptyShelfListsNothingRatherThanFailing() async {
        let result = await CLIProbe.run(["shelf", "ls", "--json"])
        #expect(result.code == 0)
        #expect((result.array as? [Any])?.isEmpty == true)
    }

    @Test func itemsAreNewestFirstAndCarryTheirPath() async throws {
        try await CLIProbe.inWorld { world in
            try Self.seed(world, names: ["one.txt", "two.txt"])
            let result = await CLIProbe.capture(["shelf", "ls", "--json"])
            let rows = result.array as? [[String: Any]] ?? []
            #expect(rows.count == 2)
            #expect(rows.first?["name"] as? String == "two.txt")
            #expect(rows.first?["exists"] as? Bool == true)
            #expect((rows.first?["path"] as? String)?.hasSuffix("two.txt") == true)
        }
    }

    @Test func addingAFileCopiesItOntoTheShelf() async throws {
        try await CLIProbe.inWorld { world in
            let source = world.sandbox.appendingPathComponent("source.txt")
            try Data("hello".utf8).write(to: source)
            let result = await CLIProbe.capture(["shelf", "add", source.path, "--json"])
            #expect(result.code == 0)
            #expect(ShelfIndex.load().count == 1)
            #expect(FileManager.default.fileExists(atPath: source.path))
        }
    }

    @Test func addingTheSameNameTwiceNeverOverwrites() async throws {
        try await CLIProbe.inWorld { world in
            let source = world.sandbox.appendingPathComponent("dupe.txt")
            try Data("hello".utf8).write(to: source)
            _ = await CLIProbe.capture(["shelf", "add", source.path])
            _ = await CLIProbe.capture(["shelf", "add", source.path])
            let names = ShelfIndex.load().map(\.name)
            #expect(names.count == 2)
            #expect(Set(names).count == 2)
        }
    }

    @Test func addingAMissingFileIsNotFound() async {
        let result = await CLIProbe.run(["shelf", "add", "/nowhere/at/all.txt"])
        #expect(result.code == ExitCodes.notFound)
    }

    @Test func removingTakesTheFileWithIt() async throws {
        try await CLIProbe.inWorld { world in
            try Self.seed(world, names: ["one.txt", "two.txt"])
            let gone = ShelfIndex.root.appendingPathComponent("two.txt")
            let result = await CLIProbe.capture(["shelf", "rm", "1", "--json"])
            #expect(result.object?["remaining"] as? Int == 1)
            #expect(!FileManager.default.fileExists(atPath: gone.path))
        }
    }

    @Test func clearingEmptiesTheWholeShelf() async throws {
        try await CLIProbe.inWorld { world in
            try Self.seed(world, names: ["a", "b", "c"])
            let result = await CLIProbe.capture(["shelf", "clear", "--json"])
            #expect(result.object?["removed"] as? Int == 3)
            #expect(ShelfIndex.load().isEmpty)
        }
    }

    @Test func anIndexOutsideTheShelfIsNotFound() async throws {
        try await CLIProbe.inWorld { world in
            try Self.seed(world, names: ["a"])
            let result = await CLIProbe.capture(["shelf", "path", "9"])
            #expect(result.code == ExitCodes.notFound)
        }
    }
}

@Suite struct CLICleanerTests {
    @Test func theCategoryListMatchesTheCatalogTheAppUses() async {
        let result = await CLIProbe.run(["cleaner", "categories", "--json"])
        #expect(result.code == 0)
        let rows = result.array as? [[String: Any]] ?? []
        #expect(rows.compactMap { $0["category"] as? String } == JunkCatalog.entries.map(\.id))
    }

    @Test func anUnknownCategoryIsNotFoundAndListsTheRealOnes() async {
        let result = await CLIProbe.run(["cleaner", "scan", "--category", "bitcoin"])
        #expect(result.code == ExitCodes.notFound)
        #expect(result.stderr.contains("categories:"))
    }

    @Test func scanningAHomeWithNoCachesFindsNothing() async throws {
        try await CLIProbe.inWorld { _ in
            let result = await CLIProbe.capture(["cleaner", "scan", "--json"])
            #expect(result.code == 0)
            #expect(result.object?["totalBytes"] as? Int == 0)
            #expect((result.object?["categories"] as? [Any])?.isEmpty == true)
        }
    }

    @Test func scanningFindsWhatIsThereAndSizesIt() async throws {
        try await CLIProbe.inWorld { world in
            let cache = world.sandbox.appendingPathComponent("Library/Caches/Homebrew/downloads")
            try FileManager.default.createDirectory(
                at: cache, withIntermediateDirectories: true)
            try Data(repeating: 7, count: 4096).write(
                to: cache.appendingPathComponent("bottle.tar.gz"))
            let result = await CLIProbe.capture([
                "cleaner", "scan", "--category", "homebrew", "--json",
            ])
            #expect(result.code == 0)
            let total = result.object?["totalBytes"] as? Int ?? 0
            #expect(total >= 4096)
            let categories = result.object?["categories"] as? [[String: Any]] ?? []
            #expect(categories.first?["category"] as? String == "homebrew")
        }
    }

    @Test func cleaningRefusesToTouchAnythingWithoutYes() async throws {
        try await CLIProbe.inWorld { world in
            let cache = world.sandbox.appendingPathComponent("Library/Caches/Homebrew/downloads")
            try FileManager.default.createDirectory(
                at: cache, withIntermediateDirectories: true)
            let file = cache.appendingPathComponent("bottle.tar.gz")
            try Data(repeating: 7, count: 4096).write(to: file)
            let result = await CLIProbe.capture([
                "cleaner", "clean", "--category", "homebrew", "--json",
            ])
            #expect(result.code == 0)
            #expect(result.object?["applied"] as? Bool == false)
            #expect(result.object?["reclaimedBytes"] as? Int == 0)
            #expect((result.object?["wouldReclaimBytes"] as? Int ?? 0) >= 4096)
            #expect(FileManager.default.fileExists(atPath: file.path))
        }
    }

    @Test func theDriveListNamesTheBootVolume() async {
        let result = await CLIProbe.run(["cleaner", "drives", "--json"])
        #expect(result.code == 0)
        let rows = result.array as? [[String: Any]] ?? []
        #expect(rows.contains { $0["id"] as? String == "/" })
    }
}

@Suite struct CLIDockerExtrasTests {
    @Test func everyPruneTargetIsAKnownDockerVerb() {
        for target in DockerPruneCommand.targets {
            let command = DockerCommands.prune(target)
            #expect(command.hasPrefix("docker "))
            #expect(command.contains("prune"))
        }
    }

    @Test func pruningVolumesIsNeverFoldedIntoSystem() {
        #expect(DockerCommands.prune("system") != DockerCommands.prune("volumes"))
        #expect(DockerCommands.prune("volumes").contains("volume prune"))
    }

    @Test func anUnknownPruneTargetIsNotFoundBeforeAnySSH() async {
        let result = await CLIProbe.run([
            "machines", "docker", "prune", "nowhere-at-all", "everything",
        ])
        #expect(result.code == ExitCodes.notFound)
        #expect(result.stderr.contains("try:"))
    }

    @Test func everyComposeVerbBuildsACommandScopedToItsProject() {
        for action in ["up -d", "down", "restart", "pull"] {
            let command = DockerCommands.composeAction(
                action, project: "web stack", directory: nil)
            #expect(command.hasPrefix("docker compose -p "))
            #expect(command.contains("'web stack'"))
            #expect(command.hasSuffix(action))
        }
    }

    @Test func composeVerbsAreReachableAsSubcommands() throws {
        for name in ["up", "down", "restart", "pull", "logs"] {
            let parsed = try EdRoot.parseAsRoot([
                "machines", "docker", "compose", name, "m", "p",
            ])
            #expect(CommandCrawler.name(of: type(of: parsed)) == name)
        }
        let listed = try EdRoot.parseAsRoot(["machines", "docker", "compose", "ls", "m"])
        #expect(CommandCrawler.name(of: type(of: listed)) == "ls")
        let bare = try EdRoot.parseAsRoot(["machines", "docker", "compose", "m"])
        #expect(CommandCrawler.name(of: type(of: bare)) == "ls")
    }

    @Test func theMachineMayComeFirstForComposeToo() {
        #expect(
            ArgumentRewriting.rewrite(
                ["machines", "tuf", "docker", "compose", "up", "web"], machines: ["tuf"])
                == ["machines", "docker", "compose", "up", "tuf", "web"])
    }
}
