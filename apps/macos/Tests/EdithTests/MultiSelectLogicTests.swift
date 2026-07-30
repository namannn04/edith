import EdithKit
import Testing

@Suite struct MultiSelectLogicTests {
    private let order = ["a", "b", "c", "d", "e"]

    @Test func toggleAddsAndRemoves() {
        let added = MultiSelectLogic.toggle("b", selection: ["a"])
        #expect(added.selection == ["a", "b"])
        #expect(added.anchor == "b")
        #expect(!added.dismiss)
        let removed = MultiSelectLogic.toggle("b", selection: ["a", "b"])
        #expect(removed.selection == ["a"])
    }

    @Test func toggleKeepsAtLeastOneSelected() {
        let outcome = MultiSelectLogic.toggle("a", selection: ["a"])
        #expect(outcome.selection == ["a"])
    }

    @Test func plainRowClickSelectsOnlyAndDismisses() {
        let outcome = MultiSelectLogic.rowClick(
            "c", order: order, selection: ["a", "b"], anchor: "a",
            toggleModifier: false, rangeModifier: false)
        #expect(outcome.selection == ["c"])
        #expect(outcome.anchor == "c")
        #expect(outcome.dismiss)
    }

    @Test func modifierRowClickTogglesWithoutDismissing() {
        let outcome = MultiSelectLogic.rowClick(
            "c", order: order, selection: ["a"], anchor: "a",
            toggleModifier: true, rangeModifier: false)
        #expect(outcome.selection == ["a", "c"])
        #expect(!outcome.dismiss)
    }

    @Test func shiftClickSelectsRangeFromAnchor() {
        let outcome = MultiSelectLogic.rowClick(
            "d", order: order, selection: ["b"], anchor: "b",
            toggleModifier: false, rangeModifier: true)
        #expect(outcome.selection == ["b", "c", "d"])
        #expect(outcome.anchor == "b")
        #expect(!outcome.dismiss)
    }

    @Test func shiftClickHandlesReversedRangeAndMissingAnchor() {
        let reversed = MultiSelectLogic.rowClick(
            "a", order: order, selection: ["c"], anchor: "c",
            toggleModifier: false, rangeModifier: true)
        #expect(reversed.selection == ["a", "b", "c"])
        let anchorless = MultiSelectLogic.rowClick(
            "d", order: order, selection: ["a"], anchor: nil,
            toggleModifier: false, rangeModifier: true)
        #expect(anchorless.selection == ["d"])
    }

    @Test func shiftClickWithStaleAnchorFallsBackToClicked() {
        let outcome = MultiSelectLogic.rowClick(
            "d", order: order, selection: ["a"], anchor: "gone",
            toggleModifier: false, rangeModifier: true)
        #expect(outcome.selection == ["d"])
        #expect(!outcome.dismiss)
    }

    @Test func actionClickSelectsOnlyThenAll() {
        let only = MultiSelectLogic.actionClick("b", order: order, selection: Set(order))
        #expect(only.selection == ["b"])
        #expect(!only.dismiss)
        let all = MultiSelectLogic.actionClick("b", order: order, selection: ["b"])
        #expect(all.selection == Set(order))
    }

    @Test func actionLabelFlipsForSoleSelection() {
        #expect(MultiSelectLogic.actionLabel("b", selection: ["a", "b"]) == "Only")
        #expect(MultiSelectLogic.actionLabel("b", selection: ["b"]) == "All")
    }

    @Test func selectAllCoversEveryOption() {
        let outcome = MultiSelectLogic.selectAll(order: order)
        #expect(outcome.selection == Set(order))
        #expect(!outcome.dismiss)
    }
}
