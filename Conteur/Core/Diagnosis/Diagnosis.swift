import Foundation

enum Dimension: String, Sendable, Hashable, CaseIterable, Codable {
    case structure
    case coherence
    case relevance
    case engagement
    case delivery
    /// Whether they told the story that was actually there. Only measurable because the
    /// app supplied the story — there is nothing to be unfaithful to otherwise.
    case fidelity

    var title: String {
        rawValue.capitalized
    }
}

/// Bands rather than a 0–100 score: the underlying measurement isn't precise enough
/// to justify two significant figures, and a score that wobbles between attempts
/// destroys trust in the comparison.
enum Band: String, Sendable, Hashable, CaseIterable, Comparable {
    /// There was not enough in the retelling to judge this at all. Distinct from
    /// `strong`, which claims something — saying a two-word retelling had strong
    /// structure is worse than saying nothing.
    case insufficient
    case emerging
    case developing
    case strong

    var label: String {
        switch self {
        case .insufficient: "Not enough to tell"
        case .emerging, .developing, .strong: rawValue.capitalized
        }
    }

    static func < (lhs: Band, rhs: Band) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }

    init(score: Double) {
        switch score {
        case ..<0.5: self = .emerging
        case ..<0.75: self = .developing
        default: self = .strong
        }
    }
}

/// A claim's receipt. Every finding must carry at least one, so no feedback can be
/// given that the speaker cannot go back and hear for themselves.
struct Evidence: Sendable, Hashable {
    /// When it happened, or nil when the finding is about something absent. You cannot
    /// point at the moment somebody failed to say something.
    let at: TimeInterval?
    let quote: String?
    let measure: String?

    static func at(_ time: TimeInterval, quote: String? = nil, measure: String? = nil) -> Evidence {
        Evidence(at: time, quote: quote, measure: measure)
    }

    /// Something the story had that the retelling did not.
    static func missing(_ quote: String, measure: String? = nil) -> Evidence {
        Evidence(at: nil, quote: quote, measure: measure)
    }

    var isLocated: Bool { at != nil }
}

struct Finding: Sendable, Hashable {
    let dimension: Dimension
    /// What this finding is *about* — an entity name, or the name of the failure.
    ///
    /// Observations carry timestamps and counts, so they read differently between
    /// attempts even when the same problem recurs. The subject is what stays constant,
    /// and it is how a second telling can be compared with a first.
    let subject: String
    /// Stated as fact, not advice. The wording that reaches the user is composed later.
    let observation: String
    /// How much of the problem there is. **Lower is better**, always — so the same
    /// problem in two attempts can be told apart from the same problem unchanged.
    let magnitude: Double
    /// How much this subtracts from the dimension's score, 0...1.
    let weight: Double
    let evidence: [Evidence]

    var identity: String { "\(dimension.rawValue)/\(subject)" }
}

struct DimensionAssessment: Sendable, Hashable {
    let dimension: Dimension
    let band: Band
    let score: Double
    let findings: [Finding]
}

struct Diagnosis: Sendable {
    let assessments: [DimensionAssessment]
    /// The single weakness worth acting on. Everything else stays collapsed.
    let focus: DimensionAssessment?

    static let empty = Diagnosis(assessments: [], focus: nil)

    func assessment(for dimension: Dimension) -> DimensionAssessment? {
        assessments.first { $0.dimension == dimension }
    }

    /// Whether anything could be judged. Distinct from having found nothing wrong.
    var isJudgeable: Bool {
        assessments.contains { $0.band != .insufficient }
    }

    /// What held up, strongest first — used when there is nothing to correct.
    var strengths: [DimensionAssessment] {
        assessments.filter { $0.band == .strong }.sorted { $0.score > $1.score }
    }
}

/// A speaker's own rolling average, so the weakness chosen is the one that has moved
/// least for them rather than whichever dimension is hardest in general.
struct Baseline: Sendable, Hashable {
    let scores: [Dimension: Double]

    static let none = Baseline(scores: [:])

    func score(for dimension: Dimension) -> Double? {
        scores[dimension]
    }
}
