import Foundation

protocol Diagnosing: Sendable {
    func diagnose(_ input: DiagnosticInput, against baseline: Baseline) -> Diagnosis
}

/// Scores every dimension from the rules that fired, then picks the one weakness
/// worth acting on. Pure and deterministic: the same recording always yields the same
/// bands and the same focus, which is what makes attempt-to-attempt comparison real.
struct RuleBasedDiagnosis: Diagnosing {
    /// A story a listener cannot follow is a bigger problem than one with fillers in
    /// it, so equal score gaps do not carry equal weight.
    private static let importance: [Dimension: Double] = [
        .fidelity: 1.1,
        .structure: 1.0,
        .coherence: 1.0,
        .relevance: 0.85,
        .engagement: 0.8,
        .delivery: 0.6,
    ]

    private let rules: [any DiagnosticRule]

    init(rules: [any DiagnosticRule] = RuleBasedDiagnosis.standardRules) {
        self.rules = rules
    }

    static let standardRules: [any DiagnosticRule] = [
        // Need the story
        OmittedEventRule(),
        OmittedCharacterRule(),
        SequenceAccuracyRule(),
        UncausedEventRule(),
        CompressionRule(),
        StakesRule(),
        InventionRule(),
        CoverageRule(),
        // Need only the recording
        RestartRule(),
        MonotoneRule(),
        FilledPauseRule(),
        StallRule(),
        // Need the recording and where the story turned
        RushedClimaxRule(),
        UnevaluatedClimaxRule(),
    ]

    func diagnose(_ input: DiagnosticInput, against baseline: Baseline) -> Diagnosis {
        guard !input.timeline.transcript.words.isEmpty else { return .empty }

        let usable = rules.filter { $0.canEvaluate(in: input) }
        let findings = usable.flatMap { $0.findings(in: input) }
        let assessments = Dimension.allCases.map { dimension in
            assess(
                dimension,
                from: findings.filter { $0.dimension == dimension },
                // A dimension can be judged when any of its rules had something to look at.
                judgeable: usable.contains { $0.dimension == dimension }
            )
        }

        return Diagnosis(
            assessments: assessments,
            focus: focus(among: assessments, against: baseline)
        )
    }

    private func assess(
        _ dimension: Dimension,
        from findings: [Finding],
        judgeable: Bool
    ) -> DimensionAssessment {
        guard judgeable else {
            return DimensionAssessment(
                dimension: dimension,
                band: .insufficient,
                score: 1,
                findings: []
            )
        }

        let deductions = findings.reduce(0) { $0 + $1.weight }
        let score = max(0, 1 - deductions)

        return DimensionAssessment(
            dimension: dimension,
            // Something was flagged here, so it cannot also be reported as strong.
            band: findings.isEmpty ? Band(score: score) : min(Band(score: score), .developing),
            score: score,
            findings: findings.sorted { $0.weight > $1.weight }
        )
    }

    /// How much better another dimension has to be before it takes the focus from the one
    /// already being worked on. Invented, and deliberately generous: the cost of moving too
    /// early is a sub-skill nobody practises twice, and the cost of staying too long is one
    /// telling spent on the second-most-useful thing.
    private static let hysteresis = 0.1

    /// The dimension that has slipped furthest from where this speaker usually sits.
    /// With no history, that reduces to the weakest dimension by importance.
    ///
    /// The dimension already being worked on keeps it unless something clears it by a margin,
    /// so a challenge survives a telling that did not quite land it.
    private func focus(among assessments: [DimensionAssessment], against baseline: Baseline) -> DimensionAssessment? {
        let candidates = assessments.filter { !$0.findings.isEmpty }
        guard
            let leader = candidates.max(by: {
                impact(of: $0, against: baseline) < impact(of: $1, against: baseline)
            })
        else { return nil }

        guard
            let standing = baseline.standingFocus,
            let held = candidates.first(where: { $0.dimension == standing }),
            impact(of: leader, against: baseline) - impact(of: held, against: baseline) <= Self.hysteresis
        else { return leader }

        return held
    }

    private func impact(of assessment: DimensionAssessment, against baseline: Baseline) -> Double {
        let reference = baseline.score(for: assessment.dimension) ?? 1
        let gap = max(0, reference - assessment.score)
        return gap * (Self.importance[assessment.dimension] ?? 1)
    }
}
