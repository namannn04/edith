import AppKit
import SwiftUI
import Testing

@testable import Edith

@Suite struct SectionWindowTests {
    @Test func commandClickDetaches() {
        #expect(SectionWindowCommand.shouldDetach(.command))
        #expect(SectionWindowCommand.shouldDetach([.command, .shift]))
        #expect(!SectionWindowCommand.shouldDetach([]))
        #expect(!SectionWindowCommand.shouldDetach(.option))
    }

    @Test func filesIsNotATabBecauseItOpensItsOwnWindow() {
        #expect(!MachineTab.allCases.map(\.rawValue).contains("files"))
        #expect(MachineTab.tabs(isLocal: true) == [.overview, .processes, .terminal])
        #expect(MachineTab.tabs(isLocal: false).contains(.docker))
    }

    @Test func everyVisibleSectionExceptAboutCanDetach() {
        let visible: [MainDestination] = [.home, .dashboard, .machines]
        let detachable = SectionWindowCommand.detachableDestinations(visibleHomeItems: visible)
        #expect(detachable.contains(.machines))
        #expect(detachable.contains(.extensions))
        #expect(detachable.contains(.settings))
        #expect(!detachable.contains(.about))
    }

    @Test func detachableListFollowsEnabledExtensions() {
        let detachable = SectionWindowCommand.detachableDestinations(visibleHomeItems: [.home])
        #expect(!detachable.contains(.music))
        #expect(detachable.first == .home)
    }
}

@Suite struct WindowTabKeyCommandTests {
    @Test func controlTabCyclesTabsOnlyWhenTabbed() {
        #expect(
            WindowTabKeyCommand.resolve(
                characters: "\t", keyCode: 48, modifiers: .control, tabbed: true) == .nextTab)
        #expect(
            WindowTabKeyCommand.resolve(
                characters: "\t", keyCode: 48, modifiers: [.control, .shift], tabbed: true)
                == .previousTab)
        #expect(
            WindowTabKeyCommand.resolve(
                characters: "\t", keyCode: 48, modifiers: .control, tabbed: false) == nil)
    }

    @Test func commandNumberSelectsTabByIndex() {
        #expect(
            WindowTabKeyCommand.resolve(
                characters: "1", keyCode: 18, modifiers: .command, tabbed: true)
                == .selectTab(index: 0))
        #expect(
            WindowTabKeyCommand.resolve(
                characters: "9", keyCode: 25, modifiers: .command, tabbed: true)
                == .selectTab(index: 8))
    }

    @Test func commandNumberIsLeftToTheSidebarWhenNotTabbed() {
        #expect(
            WindowTabKeyCommand.resolve(
                characters: "1", keyCode: 18, modifiers: .command, tabbed: false) == nil)
    }

    @Test func ignoresOutOfRangeAndExtraModifiers() {
        #expect(
            WindowTabKeyCommand.resolve(
                characters: "0", keyCode: 29, modifiers: .command, tabbed: true) == nil)
        #expect(
            WindowTabKeyCommand.resolve(
                characters: "1", keyCode: 18, modifiers: [.command, .option], tabbed: true)
                == nil)
        #expect(
            WindowTabKeyCommand.resolve(
                characters: "a", keyCode: 0, modifiers: .command, tabbed: true) == nil)
    }

    @Test func controlTabIsNotConfusedWithCommandTab() {
        #expect(
            WindowTabKeyCommand.resolve(
                characters: "\t", keyCode: 48, modifiers: [.control, .command], tabbed: true)
                == nil)
    }
}

@Suite struct FinderKeyTests {
    private func event(
        keyCode: UInt16, characters: String = "", modifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
            windowNumber: 0, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)!
    }

    @Test func returnRenamesAndCommandReturnOpens() {
        #expect(FinderKey.resolve(event: event(keyCode: 36)) == .rename)
        #expect(
            FinderKey.resolve(event: event(keyCode: 36, modifiers: .command)) == .openSelection)
    }

    @Test func arrowsMoveAndExtendSelection() {
        #expect(FinderKey.resolve(event: event(keyCode: 125)) == .moveDown(extend: false))
        #expect(
            FinderKey.resolve(event: event(keyCode: 125, modifiers: .shift))
                == .moveDown(extend: true))
        #expect(
            FinderKey.resolve(event: event(keyCode: 126, modifiers: .command))
                == .enclosingFolder)
    }

    @Test func spaceIsQuickLookAndEscapeCancels() {
        #expect(FinderKey.resolve(event: event(keyCode: 49)) == .quickLook)
        #expect(FinderKey.resolve(event: event(keyCode: 53)) == .cancel)
    }

    @Test func deleteNeedsCommandAndOptionMeansImmediate() {
        #expect(FinderKey.resolve(event: event(keyCode: 51)) == nil)
        #expect(FinderKey.resolve(event: event(keyCode: 51, modifiers: .command)) == .trash)
        #expect(
            FinderKey.resolve(event: event(keyCode: 51, modifiers: [.command, .option]))
                == .deleteImmediately)
    }

    @Test func commandLettersMapToActions() {
        #expect(
            FinderKey.resolve(event: event(keyCode: 8, characters: "c", modifiers: .command))
                == .copy)
        #expect(
            FinderKey.resolve(
                event: event(keyCode: 8, characters: "c", modifiers: [.command, .option]))
                == .copyPath)
        #expect(
            FinderKey.resolve(
                event: event(keyCode: 45, characters: "n", modifiers: [.command, .shift]))
                == .newFolder)
        #expect(
            FinderKey.resolve(event: event(keyCode: 18, characters: "1", modifiers: .command))
                == .iconView)
    }

    @Test func plainLettersTypeSelect() {
        #expect(FinderKey.resolve(event: event(keyCode: 0, characters: "a")) == .type("a"))
        #expect(
            FinderKey.resolve(event: event(keyCode: 0, characters: "a", modifiers: .option))
                == nil)
    }
}
