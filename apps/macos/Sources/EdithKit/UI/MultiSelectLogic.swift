public enum MultiSelectLogic {
    public struct Outcome<ID: Hashable>: Equatable {
        public let selection: Set<ID>
        public let anchor: ID?
        public let dismiss: Bool

        public init(selection: Set<ID>, anchor: ID?, dismiss: Bool) {
            self.selection = selection
            self.anchor = anchor
            self.dismiss = dismiss
        }
    }

    public static func toggle<ID>(
        _ id: ID, selection: Set<ID>
    ) -> Outcome<ID> {
        var next = selection
        if next.contains(id) {
            if next.count > 1 { next.remove(id) }
        } else {
            next.insert(id)
        }
        return Outcome(selection: next, anchor: id, dismiss: false)
    }

    public static func rowClick<ID>(
        _ id: ID, order: [ID], selection: Set<ID>, anchor: ID?,
        toggleModifier: Bool, rangeModifier: Bool
    ) -> Outcome<ID> {
        if rangeModifier {
            let start = anchor ?? id
            guard let a = order.firstIndex(of: start), let b = order.firstIndex(of: id) else {
                return Outcome(selection: [id], anchor: id, dismiss: false)
            }
            return Outcome(
                selection: Set(order[min(a, b)...max(a, b)]), anchor: start, dismiss: false)
        }
        if toggleModifier { return toggle(id, selection: selection) }
        return Outcome(selection: [id], anchor: id, dismiss: true)
    }

    public static func actionClick<ID>(
        _ id: ID, order: [ID], selection: Set<ID>
    ) -> Outcome<ID> {
        if selection == [id] {
            return Outcome(selection: Set(order), anchor: id, dismiss: false)
        }
        return Outcome(selection: [id], anchor: id, dismiss: false)
    }

    public static func actionLabel<ID>(_ id: ID, selection: Set<ID>) -> String {
        selection == [id] ? "All" : "Only"
    }

    public static func selectAll<ID>(order: [ID]) -> Outcome<ID> {
        Outcome(selection: Set(order), anchor: nil, dismiss: false)
    }
}
