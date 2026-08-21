import Foundation
import Testing

@testable import Conteur

struct RetellingComparisonTests {
    private let comparison = RetellingComparison()
    private let challenge = "Follow every thread you open through to its end."

    @Test func aProblemThatDoesNotComeBackCountsAsMet() {
        let progress = compare(
            first: [droppedThread("brother")],
            second: []
        )

        #expect(progress?.verdict == .met)
        #expect(progress?.resolved.map { $0.subject } == ["brother"])
        #expect(progress?.persisted.isEmpty == true)
    }

    @Test func theSameProblemUnchangedIsNotYet() {
        let progress = compare(
            first: [droppedThread("brother")],
            second: [droppedThread("brother")]
        )

        #expect(progress?.verdict == .notYet)
        #expect(progress?.persisted.map { $0.subject } == ["brother"])
    }

    @Test func aProblemThatShrankCountsAsCloser() {
        let progress = compare(
            first: [padding(0.28)],
            second: [padding(0.20)]
        )

        #expect(progress?.verdict == .closer)
    }

    @Test func aRoundingDifferenceIsNotProgress() {
        let progress = compare(
            first: [padding(0.28)],
            second: [padding(0.275)]
        )

        #expect(progress?.verdict == .notYet)
    }

    @Test func aProblemThatGrewIsNotProgress() {
        let progress = compare(
            first: [padding(0.28)],
            second: [padding(0.4)]
        )

        #expect(progress?.verdict == .notYet)
    }

    @Test func newProblemsAreReportedWithoutChangingTheVerdict() {
        let progress = compare(
            first: [droppedThread("brother")],
            second: [droppedThread("sister")]
        )

        #expect(progress?.verdict == .met)
        #expect(progress?.resolved.map { $0.subject } == ["brother"])
        #expect(progress?.introduced.map { $0.subject } == ["sister"])
    }

    @Test func attemptComparisonBuildsPerDimensionDeltas() {
        let first = Diagnosis(
            assessments: [
                dimensionAssessment(Conteur.Dimension.coherence, findings: [droppedThread("brother")]),
                dimensionAssessment(Conteur.Dimension.delivery, findings: [stalls(5)])
            ],
            focus: dimensionAssessment(Conteur.Dimension.coherence, findings: [droppedThread("brother")])
        )
        let second = Diagnosis(
            assessments: [
                dimensionAssessment(Conteur.Dimension.coherence, findings: []),
                dimensionAssessment(Conteur.Dimension.delivery, findings: [stalls(3)])
            ],
            focus: dimensionAssessment(Conteur.Dimension.coherence, findings: [])
        )

        let attemptComparison = RetellingComparison().attemptComparison(
            from: RetellingComparisonInput(first: first, second: second, challenge: challenge, mode: .continuation)
        )

        let coherence = attemptComparison.deltas.first { $0.dimension == Conteur.Dimension.coherence }
        #expect(attemptComparison.focusDimension == Conteur.Dimension.coherence)
        #expect(attemptComparison.primaryImprovement?.dimension == Conteur.Dimension.coherence)
        #expect(coherence?.improvement ?? 0 > 0)
        #expect(coherence?.resolved.map { $0.subject } == ["brother"])
    }

    @Test func standaloneDeltaSurfacesContinuationOnlyProblems() {
        let first = Diagnosis(
            assessments: [dimensionAssessment(Conteur.Dimension.structure, findings: [missingComponent("resolution")])],
            focus: dimensionAssessment(Conteur.Dimension.structure, findings: [missingComponent("resolution")])
        )
        let continuation = Diagnosis(
            assessments: [dimensionAssessment(Conteur.Dimension.structure, findings: [missingComponent("resolution")])],
            focus: dimensionAssessment(Conteur.Dimension.structure, findings: [missingComponent("resolution")])
        )
        let standalone = Diagnosis(
            assessments: [dimensionAssessment(Conteur.Dimension.structure, findings: [missingComponent("resolution"), missingComponent("setting")])],
            focus: dimensionAssessment(Conteur.Dimension.structure, findings: [missingComponent("resolution"), missingComponent("setting")])
        )

        let delta = RetellingComparison().standaloneDelta(from: first, continuation: continuation, standalone: standalone)
        #expect(delta.dimension == Conteur.Dimension.structure)
        #expect(delta.standaloneOnlyFindings.map { $0.subject } == ["setting"])
    }

    @Test func nextChallengeAdvancesAfterPrimaryImprovement() {
        let first = Diagnosis(
            assessments: [
                dimensionAssessment(Conteur.Dimension.structure, findings: [missingComponent("resolution")]),
                dimensionAssessment(Conteur.Dimension.delivery, findings: [stalls(4)])
            ],
            focus: dimensionAssessment(Conteur.Dimension.structure, findings: [missingComponent("resolution")])
        )
        let second = Diagnosis(
            assessments: [
                dimensionAssessment(Conteur.Dimension.structure, findings: []),
                dimensionAssessment(Conteur.Dimension.delivery, findings: [stalls(3)])
            ],
            focus: dimensionAssessment(Conteur.Dimension.structure, findings: [])
        )

        let attemptComparison = RetellingComparison().attemptComparison(
            from: RetellingComparisonInput(first: first, second: second, challenge: challenge, mode: .continuation)
        )
        let next = RetellingComparison().nextChallenge(after: attemptComparison, mode: .continuation)

        #expect(next != nil)
        #expect(next?.contains("delivery") == true)
    }

    // MARK: - Helpers

    private func compare(
        first findings: [Conteur.Finding],
        second: [Conteur.Finding]
    ) -> Conteur.RetellingProgress? {
        let firstDiagnosis = Diagnosis(
            assessments: [dimensionAssessment(Conteur.Dimension.coherence, findings: findings)],
            focus: findings.isEmpty ? nil : dimensionAssessment(Conteur.Dimension.coherence, findings: findings)
        )
        let secondDiagnosis = Diagnosis(
            assessments: [dimensionAssessment(Conteur.Dimension.coherence, findings: second)],
            focus: second.isEmpty ? nil : dimensionAssessment(Conteur.Dimension.coherence, findings: second)
        )
        return comparison.compare(firstDiagnosis, with: secondDiagnosis, challenge: challenge)
    }

    private func droppedThread(_ subject: String) -> Conteur.Finding {
        Conteur.Finding(
            dimension: Conteur.Dimension.coherence,
            subject: subject,
            observation: "the \(subject) thread was dropped",
            magnitude: 1,
            weight: 0.5,
            evidence: []
        )
    }

    private func padding(_ share: Double) -> Conteur.Finding {
        Conteur.Finding(
            dimension: Conteur.Dimension.relevance,
            subject: "padding",
            observation: "\(share.percentLabel) of the retelling was padding",
            magnitude: share,
            weight: 0.4,
            evidence: []
        )
    }

    private func stalls(_ count: Int) -> Conteur.Finding {
        Conteur.Finding(
            dimension: Conteur.Dimension.delivery,
            subject: "stalls",
            observation: "\(count) stalls",
            magnitude: Double(count),
            weight: 0.25,
            evidence: []
        )
    }

    private func missingComponent(_ component: String) -> Conteur.Finding {
        Conteur.Finding(
            dimension: Conteur.Dimension.structure,
            subject: component,
            observation: "missing \(component)",
            magnitude: 1,
            weight: 0.25,
            evidence: []
        )
    }

    private func dimensionAssessment(
        _ dimension: Conteur.Dimension,
        findings: [Conteur.Finding]
    ) -> Conteur.DimensionAssessment {
        let band: Conteur.Band = findings.isEmpty ? .strong : .emerging
        let score = findings.isEmpty ? 1 : 0.2
        return Conteur.DimensionAssessment(dimension: dimension, band: band, score: score, findings: findings)
    }
}

private extension Double {
    var percentLabel: String {
        String(format: "%.0f%%", self * 100)
    }
}
