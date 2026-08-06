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
