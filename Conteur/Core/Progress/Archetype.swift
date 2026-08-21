import Foundation

/// What kind of teller somebody turned out to be, named for the two dimensions they are
/// habitually strongest at.
///
/// A mix rather than a rank: nobody is good at storytelling in general, they are good at
/// holding a shape, or at landing a point, or at saying it well. The pair is what carries
/// that, and it is why this is unordered — The Cartographer is not above or below The
/// Performer, it is a different thing to be.
struct Archetype: Sendable, Hashable {
    let name: String
    let pair: DimensionPair
    /// How many of the recent tellings had both dimensions Strong, and how many were looked
    /// at. Shown as `3 / 5`, so the claim carries its own evidence.
    let met: Int
    let considered: Int

    var summary: String {
        "\(pair.first.title.lowercased()) + \(pair.second.title.lowercased())"
    }
}

/// Two dimensions, order-independent, so `structure + fidelity` and `fidelity + structure`
/// are the same pair and cannot both be named.
struct DimensionPair: Sendable, Hashable {
    let first: Dimension
    let second: Dimension

    init(_ a: Dimension, _ b: Dimension) {
        let ordered = [a, b].sorted { $0.rawValue < $1.rawValue }
        first = ordered[0]
        second = ordered[1]
    }
}

extension Archetype {
    /// How far back to look, and how much of that window the pair has to hold. Short enough
    /// that an archetype reflects who somebody is now rather than who they were in March.
    static let window = 5
    static let required = 3

    /// The pairs worth a name of their own. Anything else gets one derived from its
    /// dimensions, so no combination renders blank — there are fifteen pairs and inventing
    /// fifteen names would mean inventing nine nobody will read.
    private static let named: [DimensionPair: String] = [
        DimensionPair(.structure, .fidelity): "The Chronicler",
        DimensionPair(.structure, .coherence): "The Architect",
        DimensionPair(.structure, .engagement): "The Dramatist",
        DimensionPair(.engagement, .delivery): "The Performer",
        DimensionPair(.fidelity, .relevance): "The Witness",
        DimensionPair(.coherence, .relevance): "The Cartographer",
    ]

    /// The strongest qualifying pair, or nil when no pair has held.
    ///
    /// Nil is a real answer and the screen says so plainly. Naming an archetype off one good
    /// telling would make the label meaningless by the third session.
    static func over(_ history: [StoredRetelling]) -> Archetype? {
        let recent = Array(history.prefix(window))
        guard recent.count >= required else { return nil }

        var best: Archetype?
        for (index, first) in Dimension.allCases.enumerated() {
            for second in Dimension.allCases[(index + 1)...] {
                let pair = DimensionPair(first, second)
                let met = recent.count { telling in
                    isStrong(telling, first) && isStrong(telling, second)
                }
                guard met >= required else { continue }
                let candidate = Archetype(
                    name: named[pair] ?? derivedName(for: pair),
                    pair: pair,
                    met: met,
                    considered: recent.count
                )
                if met > (best?.met ?? 0) { best = candidate }
            }
        }
        return best
    }

    private static func isStrong(_ telling: StoredRetelling, _ dimension: Dimension) -> Bool {
        telling.scores[dimension].map { Band(score: $0) == .strong } == true
    }

    private static func derivedName(for pair: DimensionPair) -> String {
        "\(pair.first.title) & \(pair.second.title)"
    }
}
