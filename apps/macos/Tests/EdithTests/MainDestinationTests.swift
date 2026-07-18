import Testing
@testable import Edith

@Suite struct MainDestinationTests {
    @Test func sidebarSectionsAreDisjointAndCoverAllDestinations() {
        let listed = MainDestination.homeItems + MainDestination.appItems
        #expect(Set(listed).count == listed.count)
        #expect(Set(listed) == Set(MainDestination.allCases))
    }

    @Test func rawValuesRoundTrip() {
        for destination in MainDestination.allCases {
            #expect(MainDestination(rawValue: destination.rawValue) == destination)
        }
    }

    @Test func titlesAreUniqueAndNonEmpty() {
        let titles = MainDestination.allCases.map(\.title)
        #expect(Set(titles).count == titles.count)
        #expect(titles.allSatisfy { !$0.isEmpty })
    }

    @Test func iconsAreUniqueAndNonEmpty() {
        let icons = MainDestination.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
        #expect(icons.allSatisfy { !$0.isEmpty })
    }

    @Test func paperBackgroundOnlyForHomeItems() {
        for destination in MainDestination.homeItems {
            #expect(destination.usesPaperBackground)
        }
        for destination in MainDestination.appItems {
            #expect(!destination.usesPaperBackground)
        }
    }

    @Test func allFeaturesOnShowsEveryHomeItem() {
        let visible = MainDestination.visibleHomeItems(
            usage: true, music: true, calendar: true, system: true)
        #expect(visible == MainDestination.homeItems)
    }

    @Test func disabledFeaturesHideTheirPages() {
        let visible = MainDestination.visibleHomeItems(
            usage: false, music: false, calendar: false, system: false)
        #expect(visible == [.home])
    }

    @Test func eachToggleHidesExactlyItsPage() {
        let cases: [(MainDestination, [MainDestination])] = [
            (
                .dashboard,
                MainDestination.visibleHomeItems(
                    usage: false, music: true, calendar: true, system: true)
            ),
            (
                .music,
                MainDestination.visibleHomeItems(
                    usage: true, music: false, calendar: true, system: true)
            ),
            (
                .calendar,
                MainDestination.visibleHomeItems(
                    usage: true, music: true, calendar: false, system: true)
            ),
            (
                .system,
                MainDestination.visibleHomeItems(
                    usage: true, music: true, calendar: true, system: false)
            ),
        ]
        for (hidden, visible) in cases {
            #expect(!visible.contains(hidden))
            #expect(visible.count == MainDestination.homeItems.count - 1)
        }
    }

    @Test func resolveFallsBackToHomeForHiddenSelection() {
        let visible = MainDestination.visibleHomeItems(
            usage: false, music: true, calendar: true, system: true)
        #expect(MainDestination.resolve("dashboard", visibleHome: visible) == .home)
        #expect(MainDestination.resolve("music", visibleHome: visible) == .music)
    }

    @Test func resolveKeepsAppItemsAndRejectsGarbage() {
        let visible = MainDestination.visibleHomeItems(
            usage: false, music: false, calendar: false, system: false)
        for item in MainDestination.appItems {
            #expect(MainDestination.resolve(item.rawValue, visibleHome: visible) == item)
        }
        #expect(MainDestination.resolve("nonsense", visibleHome: visible) == .home)
        #expect(MainDestination.resolve("usage", visibleHome: visible) == .home)
        #expect(MainDestination.resolve("permissions", visibleHome: visible) == .home)
    }
}
