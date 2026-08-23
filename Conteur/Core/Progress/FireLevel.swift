import Foundation

/// How established a teller is — the one measure that only goes forward.
///
/// Ordered, and earned by volume and consistency rather than by which dimensions are strong.
/// That is what keeps it separate from `Archetype`: this says how long you have been at it,
/// the archetype says what kind of teller you turned out to be.
enum FireLevel: String, Sendable, Hashable, CaseIterable, Comparable, Codable {
    case unlit
    case spark
    case kindling
    case steadyFlame
    case bonfire
    case beacon

    var label: String {
        switch self {
        case .unlit: "Unlit"
        case .spark: "Spark"
        case .kindling: "Kindling"
        case .steadyFlame: "Steady Flame"
        case .bonfire: "Bonfire"
        case .beacon: "Beacon"
        }
    }

    /// What reaching this took, phrased so it can be shown as the thing still to do.
    ///
    /// Only ever read off a `next` level, and `unlit` is nobody's next — it is where you
    /// start. Its case exists for exhaustiveness and is not shown anywhere.
    var requirement: String {
        switch self {
        case .unlit: "tell a story"
        case .spark: "finish one telling"
        case .kindling: "three tellings"
        case .steadyFlame: "two dimensions Strong in one telling"
        case .bonfire: "five tellings with Engagement above Developing"
        case .beacon: "all six dimensions Strong in one telling"
        }
    }

    var next: FireLevel? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    private var rank: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    static func < (lhs: FireLevel, rhs: FireLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Where a teller stands, and how far the next level is.
struct FireStanding: Sendable, Hashable {
    let level: FireLevel
    let next: FireLevel?
    /// How many of the next level's requirement are met, and of how many. `nil` when the
    /// next level is a single event rather than a count, where a fraction would be a lie.
    let progress: Progress?

    struct Progress: Sendable, Hashable {
        let done: Int
        let needed: Int
    }
}

extension FireLevel {
    private static let kindlingTellings = 3
    private static let bonfireTellings = 5

    /// Reads a history in one pass and returns the highest level it satisfies.
    ///
    /// Every rung is checked independently rather than assuming the one below it, so a
    /// history that skips a condition — all six Strong on a third telling, say — still lands
    /// where it earned rather than where it stepped.
    static func standing(over history: [StoredRetelling]) -> FireStanding {
        guard !history.isEmpty else {
            return FireStanding(level: .unlit, next: .spark, progress: nil)
        }

        let engaging = history.count { ($0.band(for: .engagement)).map { $0 > .developing } == true }
        let strongCounts = history.map(\.strongDimensions)

        var level = FireLevel.spark
        if history.count >= kindlingTellings { level = .kindling }
        if strongCounts.contains(where: { $0 >= 2 }) { level = max(level, .steadyFlame) }
        if engaging >= bonfireTellings { level = max(level, .bonfire) }
        if strongCounts.contains(where: { $0 == Dimension.allCases.count }) { level = .beacon }

        return FireStanding(
            level: level,
            next: level.next,
            progress: progress(towards: level.next, tellings: history.count, engaging: engaging)
        )
    }

    private static func progress(
        towards next: FireLevel?,
        tellings: Int,
        engaging: Int
    ) -> FireStanding.Progress? {
        switch next {
        case .kindling: FireStanding.Progress(done: tellings, needed: kindlingTellings)
        case .bonfire: FireStanding.Progress(done: engaging, needed: bonfireTellings)
        // The rest turn on a single telling clearing a bar, and there is no honest
        // fraction of that — you have either had one or you have not.
        default: nil
        }
    }
}
