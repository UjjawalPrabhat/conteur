/// Everything measured from one retelling, which is all a rule may look at.
struct DiagnosticInput: Sendable {
    let timeline: FeatureTimeline
    let narrative: NarrativeReading

    static let empty = DiagnosticInput(timeline: .empty, narrative: .empty)
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
