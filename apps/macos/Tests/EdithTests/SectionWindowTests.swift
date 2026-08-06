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
