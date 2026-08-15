import Foundation

struct MissingComponentsRule: DiagnosticRule {
    let dimension = Dimension.structure

    func canEvaluate(in input: DiagnosticInput) -> Bool { !input.narrative.beats.isEmpty }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let arc = input.narrative.arc
        guard !input.narrative.beats.isEmpty else { return [] }

        let missing = arc.missing.sorted { $0.rawValue < $1.rawValue }
        guard !missing.isEmpty else { return [] }

        return missing.map { component in
            Finding(
                dimension: dimension,
                subject: component.rawValue,
                observation: "the retelling never established \(component.spokenName)",
                magnitude: 1,
                weight: 0.25,
                evidence: [Evidence(at: 0, quote: nil, measure: nil)]
            )
        }
    }
}

/// Time spent on stretches that do not carry the story. This is arithmetic over the
/// labelled beats, which is what lets the finding name a duration and a moment.
struct TimeAllocationRule: DiagnosticRule {
    /// Some context and colour is what makes a retelling worth listening to; past
    /// this share it is displacing the story.
    private static let toleratedShare = 0.25

    let dimension = Dimension.relevance

    func canEvaluate(in input: DiagnosticInput) -> Bool { !input.narrative.beats.isEmpty }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let beats = input.narrative.beats
        let total = beats.reduce(0) { $0 + $1.duration }
        guard total > 0 else { return [] }

        let lowValue = beats.filter { $0.kind == .lowValue || $0.kind == .offTopic }
        let spent = lowValue.reduce(0) { $0 + $1.duration }
        let share = spent / total
        guard share > Self.toleratedShare, let longest = lowValue.max(by: { $0.duration < $1.duration })
        else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "padding",
                observation: "\(share.percentLabel) of the time went to detail the story did not turn on, the longest stretch being \(longest.duration.secondsLabel) from \(longest.start.timestampLabel)",
                magnitude: share,
                weight: 0.35,
                evidence: [
                    Evidence(
                        at: longest.start,
                        quote: longest.summary,
                        measure: longest.duration.secondsLabel
                    )
                ]
            )
        ]
    }
}

private extension StoryComponent {
    /// Feedback names these in plain language, never as rubric terms.
    var spokenName: String {
        switch self {
        case .setting: "where and when it happens"
        case .initiatingEvent: "what set the story in motion"
        case .goal: "what anybody was trying to do"
        case .conflict: "what went wrong"
        case .attempts: "what was tried in response"
        case .consequences: "what came of it"
        case .resolution: "how it ended up"
        }
    }
}

extension Double {
    var percentLabel: String {
        formatted(.percent.precision(.fractionLength(0)))
    }
}
