/// Everything measured from one retelling, which is all a rule may look at.
struct DiagnosticInput: Sendable {
    let timeline: FeatureTimeline
    let narrative: NarrativeReading
    let readingProgress: ReadingProgress?

    static let empty = DiagnosticInput(
        timeline: .empty,
        narrative: .empty,
        readingProgress: nil
    )
}

/// Continuity state accumulated across chapters or previous sessions so the rules
/// can suppress findings that depend on context already established elsewhere.
struct ReadingProgress: Sendable, Hashable {
    /// Chapters or sessions that came before this one.
    let previousSessions: Int
    /// Components the reader has already covered in prior sessions.
    let coveredComponents: Set<StoryComponent>
    /// Whether stakes have been stated in a prior session.
    let stakesEstablished: Bool
    /// Entities introduced in prior sessions that are still considered live.
    let knownEntities: Set<String>

    static let none = ReadingProgress(
        previousSessions: 0,
        coveredComponents: [],
        stakesEstablished: false,
        knownEntities: []
    )

    var isContinuation: Bool { previousSessions > 0 }
}

/// One kind of finding. Rules are value types held in a collection, so covering a new
/// failure means adding a rule rather than editing existing logic.
protocol DiagnosticRule: Sendable {
    var dimension: Dimension { get }

    /// Whether this rule had enough to look at. A rule that cannot evaluate is not the
    /// same as a rule that found nothing wrong, and a dimension where nothing could be
    /// evaluated must say so rather than report strength.
    func canEvaluate(in input: DiagnosticInput) -> Bool

    func findings(in input: DiagnosticInput) -> [Finding]
}

extension DiagnosticRule {
    func canEvaluate(in input: DiagnosticInput) -> Bool { true }
}
