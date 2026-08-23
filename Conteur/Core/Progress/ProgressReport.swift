import Foundation

/// Everything the Progress tab shows, computed in one pass over history.
///
/// Pure over `[StoredRetelling]` — no model, no SwiftData, no SwiftUI — so it is testable on
/// a Mac with no device, which is the same property that made `Diagnosis` testable and the
/// reason the numbers on this screen can be trusted at all.
struct ProgressReport: Sendable {
    let tellings: Int
    let wordsTold: Int
    let timeAtTheFire: TimeInterval
    let retoldTwice: Int

    let standing: FireStanding
    let archetype: Archetype?
    let badges: [Badge]

    /// Each dimension against the four weeks before the last four, so "+17%" means the
    /// recent stretch against what came before it rather than against a fixed origin.
    let deltas: [DimensionDelta]
    /// Pace per telling, oldest first, for the sparkline.
    let pace: [PacePoint]
    /// The one thing worth working on, when history says the same failure keeps recurring.
    let workOnThis: Claim?
    /// What has held long enough to be stated as fact.
    let alreadyTrue: [Claim]
    let bestHour: Int?
    let byGenre: [GenreTally]
    /// The fixed story, told more than once — the only comparison here where the difficulty
    /// was held still. Nil until there are two of them to compare.
    let benchmark: Claim?

    static let empty = ProgressReport(
        tellings: 0,
        wordsTold: 0,
        timeAtTheFire: 0,
        retoldTwice: 0,
        standing: FireStanding(level: .unlit, next: .spark, progress: nil),
        archetype: nil,
        badges: [],
        deltas: [],
        pace: [],
        workOnThis: nil,
        alreadyTrue: [],
        bestHour: nil,
        byGenre: [],
        benchmark: nil
    )
}

struct DimensionDelta: Sendable, Hashable, Identifiable {
    let dimension: Dimension
    /// Change as a fraction, so 0.17 renders as +17%. Nil when there is no earlier stretch
    /// to compare against, which is not the same as no change.
    let change: Double?

    var id: Dimension { dimension }
}

struct PacePoint: Sendable, Hashable {
    let at: Date
    let wordsPerMinute: Double
}

struct GenreTally: Sendable, Hashable, Identifiable {
    let genre: Genre
    let tellings: Int
    var id: Genre { genre }
}

/// A statement about a teller, and the count that earns it.
///
/// Every claim carries its own arithmetic. This is the same rule the feedback screen follows
/// — nothing is asserted that cannot be pointed at — applied to aggregates, where the
/// temptation to generalise is strongest.
struct Claim: Sendable, Hashable, Identifiable {
    let id: String
    let statement: String
    let of: Int
    let out: Int

    var evidence: String { "\(of) of \(out)" }
}

extension ProgressReport {
    /// How much history a delta compares. Four weeks each side: long enough that one bad
    /// evening does not move it, short enough to notice a month of work.
    private static let stretch: TimeInterval = 28 * 24 * 60 * 60
    /// A failure has to recur across most of a window before it is worth naming.
    private static let claimWindow = 10
    private static let recurring = 4

    static func over(_ history: [StoredRetelling], now: Date = Date()) -> ProgressReport {
        guard !history.isEmpty else { return .empty }
        let newestFirst = history.sorted { $0.recordedAt > $1.recordedAt }

        return ProgressReport(
            tellings: newestFirst.count,
            wordsTold: newestFirst.reduce(0) { $0 + $1.wordCount },
            timeAtTheFire: newestFirst.reduce(0) { $0 + $1.duration },
            retoldTwice: Set(newestFirst.filter { $0.attempt > 1 }.compactMap(\.groupID)).count,
            standing: FireLevel.standing(over: newestFirst),
            archetype: Archetype.over(newestFirst),
            badges: Badge.earned(over: newestFirst),
            deltas: deltas(in: newestFirst, now: now),
            pace: newestFirst.reversed().compactMap { telling in
                telling.pace.map { PacePoint(at: telling.recordedAt, wordsPerMinute: $0) }
            },
            workOnThis: workOnThis(in: newestFirst),
            alreadyTrue: alreadyTrue(in: newestFirst),
            bestHour: bestHour(in: newestFirst),
            byGenre: byGenre(in: newestFirst),
            benchmark: benchmark(in: newestFirst)
        )
    }

    private static func deltas(in history: [StoredRetelling], now: Date) -> [DimensionDelta] {
        let recent = history.filter { now.timeIntervalSince($0.recordedAt) <= stretch }
        let earlier = history.filter {
            let age = now.timeIntervalSince($0.recordedAt)
            return age > stretch && age <= stretch * 2
        }

        return Dimension.allCases.map { dimension in
            guard
                let now = StoredRetelling.mean(of: recent, for: dimension),
                let before = StoredRetelling.mean(of: earlier, for: dimension),
                before > 0
            else { return DimensionDelta(dimension: dimension, change: nil) }
            return DimensionDelta(dimension: dimension, change: (now - before) / before)
        }
    }

    /// The failure that keeps coming back.
    ///
    /// Derived from what the rules actually reported, never from a score. A score says a
    /// dimension is weak; only the finding subject says the cause was the same cause each
    /// time, which is the difference between a diagnosis and a complaint.
    private static func workOnThis(in history: [StoredRetelling]) -> Claim? {
        let window = Array(history.prefix(claimWindow)).filter { !$0.findingSubjects.isEmpty }
        guard window.count >= recurring else { return nil }

        var counts: [RecurringFailure: Int] = [:]
        for telling in window {
            let families = Set(telling.findingSubjects.map { RecurringFailure(subject: $0) })
            for family in families { counts[family, default: 0] += 1 }
        }

        // The most persistent failure that has something to say. Family breaks a tie, so the
        // same history always names the same failure rather than whichever the dictionary
        // happened to yield first.
        let ranked = counts
            .filter { $0.value >= recurring && $0.key.advice != nil }
            .sorted { lhs, rhs in
                lhs.value == rhs.value
                    ? lhs.key.family < rhs.key.family
                    : lhs.value > rhs.value
            }
        guard let (failure, count) = ranked.first, let advice = failure.advice else { return nil }

        return Claim(id: failure.family, statement: advice, of: count, out: window.count)
    }

    /// What has held often enough to be stated without hedging.
    private static func alreadyTrue(in history: [StoredRetelling]) -> [Claim] {
        var claims: [Claim] = []
        let window = Array(history.prefix(claimWindow))

        for dimension in Dimension.allCases {
            let strong = window.count { $0.isStrong(dimension) }
            guard strong * 2 > window.count, strong >= 3 else { continue }
            claims.append(
                Claim(
                    id: "strong-\(dimension.rawValue)",
                    statement: "\(dimension.title) is Strong more often than not.",
                    of: strong,
                    out: window.count
                )
            )
        }

        if let secondTellings = secondTellingsImprove(in: history) { claims.append(secondTellings) }
        return claims
    }

    /// Whether telling it again actually helps, which is the claim the whole loop rests on.
    private static func secondTellingsImprove(in history: [StoredRetelling]) -> Claim? {
        let groups = Dictionary(grouping: history.compactMap { telling -> (UUID, StoredRetelling)? in
            telling.groupID.map { ($0, telling) }
        }, by: \.0).mapValues { $0.map(\.1) }

        let pairs = groups.values.filter { $0.count > 1 }
        guard pairs.count >= 3 else { return nil }

        let better = pairs.count { attempts in
            let ordered = attempts.sorted { $0.attempt < $1.attempt }
            guard
                let first = ordered.first, let last = ordered.last,
                let focus = first.focusDimension,
                let before = first.scores[focus], let after = last.scores[focus]
            else { return false }
            return after > before
        }
        guard better * 2 > pairs.count else { return nil }

        return Claim(
            id: "second-telling",
            statement: "Your second telling is better than your first.",
            of: better,
            out: pairs.count
        )
    }

    /// The fixed story, then and now.
    ///
    /// Every other number on this screen compares tellings of different stories, so a rise
    /// could be a better teller or an easier story. This is the one series where the story is
    /// the same one, which is what makes it the only honest measure of getting better.
    ///
    /// Counted in dimensions that held rather than averaged into a score: the measurement is
    /// banded precisely because it is not precise enough to average.
    private static func benchmark(in history: [StoredRetelling]) -> Claim? {
        let tellings = history.filter(\.isBenchmark)
        guard let latest = tellings.first, let earliest = tellings.last, tellings.count >= 2
        else { return nil }

        let now = latest.strongDimensions
        let then = earliest.strongDimensions
        let direction = now > then ? "up from" : now < then ? "down from" : "the same as"

        return Claim(
            id: "benchmark",
            statement: "On the fixed story, \(now) of \(Dimension.allCases.count) dimensions held — \(direction) \(then) the first time you told it.",
            of: now,
            out: Dimension.allCases.count
        )
    }

    private static func bestHour(in history: [StoredRetelling], calendar: Calendar = .current) -> Int? {
        var totals: [Int: (sum: Double, count: Int)] = [:]
        for telling in history {
            let hour = calendar.component(.hour, from: telling.recordedAt)
            let mean = Dimension.allCases.compactMap { telling.scores[$0] }
            guard !mean.isEmpty else { continue }
            let score = mean.reduce(0, +) / Double(mean.count)
            let running = totals[hour] ?? (0, 0)
            totals[hour] = (running.sum + score, running.count + 1)
        }
        // One good evening is not a time of day. Two is the least that can suggest one.
        return totals
            .filter { $0.value.count >= 2 }
            .max { $0.value.sum / Double($0.value.count) < $1.value.sum / Double($1.value.count) }?
            .key
    }

    private static func byGenre(in history: [StoredRetelling]) -> [GenreTally] {
        let counts = history.compactMap(\.genre).reduce(into: [Genre: Int]()) { $0[$1, default: 0] += 1 }
        return Genre.allCases.compactMap { genre in
            counts[genre].map { GenreTally(genre: genre, tellings: $0) }
        }
    }
}

/// Turns a finding subject back into something worth saying about a run of tellings.
///
/// Two of the rules build their subject per entity or per beat — `missing-Mira`,
/// `uncaused-3` — so counting raw subjects across tellings of different stories would never
/// aggregate: leaving Mira out twice and Nadia out twice reads as four separate problems
/// rather than one habit. Everything is folded to its family before it is counted.
///
/// The observations beside these subjects are written for one telling and read oddly in
/// aggregate ("you left out the bell at 0:41"), so the aggregate sentence is written here.
struct RecurringFailure: Hashable {
    let family: String

    init(subject: String) {
        if subject.hasPrefix("missing-") {
            family = "missing"
        } else if subject.hasPrefix("uncaused-") {
            family = "uncaused"
        } else {
            family = subject
        }
    }

    /// Nil for anything unrecognised. A claim with no sentence is not shown at all, which is
    /// better than showing a raw subject to somebody who has never seen the source.
    var advice: String? {
        switch family {
        case "omitted-events": "Events keep going missing. Reach the end of the story, even briefly."
        case "missing": "You leave people out. Name who is there before they do anything."
        case "order": "Order keeps slipping. Tell it forwards, even when you remember it backwards."
        case "uncaused": "Things keep happening without their cause. Say why before you say what."
        case "skeletal": "Your tellings run thin. Give the middle of the story more room."
        case "padded": "Your tellings run long. The story is shorter than the telling keeps being."
        case "stakes": "The point does not come through. Say why the story was worth telling."
        case "invented-names": "Names appear that the story never had. Stay with the people who were in it."
        case "coverage": "Too little of the story gets told to judge the rest of it."
        case "pitch": "Your voice stays level. Let the turn sound different from the setup."
        case "unevaluated-climax": "The turn keeps arriving flat. Say why it mattered, in the moment it happens."
        case "fillers": "Fillers keep creeping in. A pause carries better than an \"um\"."
        case "stalls": "Long silences keep landing mid-sentence rather than between them."
        case "restarts": "Sentences keep getting abandoned and restarted."
        case "climax-pace": "You speed up at the turning point, which is the moment that needs room."
        default: nil
        }
    }
}
