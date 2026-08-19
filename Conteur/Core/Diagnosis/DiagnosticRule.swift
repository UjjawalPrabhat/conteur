/// Everything measured from one retelling, which is all a rule may look at.
struct DiagnosticInput: Sendable {
    let timeline: FeatureTimeline
    /// The retelling measured against the story it came from. Rules read this rather than
    /// an inferred structure, which is why most of them can compute rather than judge.
    let comparison: SourceComparison

    static func nothing(for story: GuidedStory) -> DiagnosticInput {
        DiagnosticInput(timeline: .empty, comparison: .nothing(for: story))
    }
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
