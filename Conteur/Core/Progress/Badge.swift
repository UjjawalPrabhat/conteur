import Foundation

/// A thing that happened once and stays true.
///
/// Unordered and cumulative, which is what separates these from `FireLevel`: a level is
/// where you are, a badge is something you did. Each one is a predicate over history and
/// nothing else, so a badge can never be awarded by a rule that has drifted.
struct Badge: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    /// What earned it, in the past tense, so a list of badges reads as a record.
    let detail: String

    static let all: [Badge] = [
        Badge(id: "first-fire", name: "First Fire", detail: "You told one all the way through"),
        Badge(id: "held-it", name: "Held It", detail: "You met a challenge on the second telling"),
        Badge(id: "unbroken", name: "Unbroken", detail: "Three stories running, you told each one twice"),
        Badge(id: "night-owl", name: "Night Owl", detail: "Five tellings after nine at night"),
        Badge(id: "faithful", name: "Faithful", detail: "A telling with nothing invented and nothing left out"),
        Badge(id: "long-way-round", name: "Long Way Round", detail: "You have told all three kinds of story"),
    ]
}

extension Badge {
    private static let nightHour = 21
    private static let owlTellings = 5
    private static let unbrokenRun = 3

    /// Which badges a history has earned, in the order they are declared rather than the
    /// order they were won — the set is small and a stable order reads better than a
    /// chronological one nobody remembers.
    static func earned(over history: [StoredRetelling], calendar: Calendar = .current) -> [Badge] {
        guard !history.isEmpty else { return [] }

        var earned: Set<String> = ["first-fire"]

        // The verdict itself, not the fact of a second telling. Telling it again is not
        // meeting the challenge, and a badge that says "you met one" has to be able to point
        // at the telling where that was decided.
        if history.contains(where: { $0.challengeVerdict == .met }) { earned.insert("held-it") }

        let nightly = history.count { calendar.component(.hour, from: $0.recordedAt) >= nightHour }
        if nightly >= owlTellings { earned.insert("night-owl") }

        if longestRunOfRetold(in: history) >= unbrokenRun { earned.insert("unbroken") }

        // Nothing invented and nothing left out is fidelity at its ceiling, which is the one
        // dimension where Strong genuinely means the retelling was faithful.
        if history.contains(where: { $0.isStrong(.fidelity) }) { earned.insert("faithful") }

        let genres = Set(history.compactMap(\.genre))
        if genres.count == Genre.allCases.count { earned.insert("long-way-round") }

        return all.filter { earned.contains($0.id) }
    }

    /// The longest run of consecutive stories that were each told more than once.
    ///
    /// Grouped by `groupID` rather than counted over records, because three attempts at one
    /// story is persistence at a single story, not a run of three.
    private static func longestRunOfRetold(in history: [StoredRetelling]) -> Int {
        var seen: [UUID] = []
        var retold: Set<UUID> = []
        for telling in history.reversed() {
            guard let group = telling.groupID else { continue }
            if !seen.contains(group) { seen.append(group) }
            if telling.attempt > 1 { retold.insert(group) }
        }

        var longest = 0
        var run = 0
        for group in seen {
            run = retold.contains(group) ? run + 1 : 0
            longest = max(longest, run)
        }
        return longest
    }
}
