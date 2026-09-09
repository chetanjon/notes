import Foundation

/// "Sort the list": the model labels each item with a kind, and the order
/// follows from the labels here, items of the same kind together in the
/// order their kind first appears. Models label well and permute badly,
/// so the permutation is never theirs to write. Pure, tested.
enum ListSorter {
    /// Each item's index in the new order, first for the top, from the
    /// model's `(number, group)` pairs for a list of `count` items. Nil
    /// when a number is missing, repeated or out of range, or when the
    /// order would be the one the list already has.
    static func order(groups: [(number: Int, group: String)], count: Int) -> [Int]? {
        guard count > 0 else { return nil }
        // An item the model skipped keeps a kind of its own, so a partial
        // answer still groups what it did label instead of being thrown away.
        var kind = (0..<count).map { "item \($0)" }
        var seen = Set<Int>()
        for pair in groups {
            let name = pair.group.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            guard pair.number >= 1, pair.number <= count, !name.isEmpty,
                  seen.insert(pair.number).inserted else { continue }
            kind[pair.number - 1] = name
        }
        // One kind for everything, or a label each, is not a grouping.
        let named = Set(seen.map { kind[$0 - 1] })
        guard named.count >= 2 else { return nil }
        var rank: [String: Int] = [:]
        for name in kind where rank[name] == nil { rank[name] = rank.count }
        let result = Array(0..<count).sorted { a, b in
            let ra = rank[kind[a]] ?? 0, rb = rank[kind[b]] ?? 0
            return ra != rb ? ra < rb : a < b
        }
        return result == Array(0..<count) ? nil : result
    }
}
