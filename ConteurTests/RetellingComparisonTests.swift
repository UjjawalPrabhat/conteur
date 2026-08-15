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
        #expect(progress?.resolved.map(\.subject) == ["brother"])
        #expect(progress?.persisted.isEmpty == true)
    }

    @Test func theSameProblemUnchangedIsNotYet() {
        let progress = compare(
            first: [droppedThread("brother")],
            second: [droppedThread("brother")]
        )

        #expect(progress?.verdict == .notYet)
        #expect(progress?.persisted.map(\.subject) == ["brother"])
    }

    /// Somebody who went from 28% padding to 20% improved. Telling them they failed is
    /// both wrong and the fastest way to lose them.
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

        // The thread they were asked about was carried; a different one was dropped.
        #expect(progress?.verdict == .met)
        #expect(progress?.introduced.map(\.subject) == ["sister"])
    }

    @Test func nothingCanBeComparedWhenNeitherTellingCouldBeJudged() {
        let empty = Diagnosis(assessments: [], focus: nil)
        #expect(comparison.compare(empty, with: empty, challenge: challenge) == nil)
    }

    /// A clean first telling gets a stretch challenge rather than a correction, and it
    /// still has to be possible to say whether the stretch held.
    @Test func aCleanTellingFollowedByACleanTellingMeetsTheStretch() {
        let progress = comparison.compare(
            diagnosis(with: []),
            with: diagnosis(with: []),
            challenge: "Tell it again in half the time."
        )

        #expect(progress?.verdict == .met)
    }

    @Test func aCleanTellingThatPicksUpProblemsHasNotMetTheStretch() {
        let progress = comparison.compare(
            diagnosis(with: []),
            with: diagnosis(with: [droppedThread("brother")]),
            challenge: "Tell it again in half the time."
        )

        #expect(progress?.verdict == .notYet)
        #expect(progress?.introduced.map(\.subject) == ["brother"])
    }

    // MARK: - Fixtures

    private func compare(first: [Finding], second: [Finding]) -> RetellingProgress? {
        comparison.compare(
            diagnosis(with: first),
            with: diagnosis(with: second),
            challenge: challenge
        )
    }

    private func diagnosis(with findings: [Finding]) -> Diagnosis {
        let assessment = DimensionAssessment(
            dimension: .coherence,
            band: findings.isEmpty ? .strong : .developing,
            score: max(0, 1 - findings.reduce(0) { $0 + $1.weight }),
            findings: findings
        )
        // A dimension with nothing wrong is never the focus, which is what makes a clean
        // telling take the stretch-challenge path.
        return Diagnosis(assessments: [assessment], focus: findings.isEmpty ? nil : assessment)
    }

    private func droppedThread(_ entity: String) -> Finding {
        Finding(
            dimension: .coherence,
            subject: entity,
            observation: "\(entity) was introduced and never came up again",
            magnitude: 1,
            weight: 0.3,
            evidence: [Evidence(at: 47, quote: nil, measure: nil)]
        )
    }

    private func padding(_ share: Double) -> Finding {
        Finding(
            dimension: .coherence,
            subject: "padding",
            observation: "\(Int(share * 100))% went to detail the story did not turn on",
            magnitude: share,
            weight: 0.35,
            evidence: [Evidence(at: 0, quote: nil, measure: nil)]
        )
    }
}
