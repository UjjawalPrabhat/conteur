import Foundation
import Testing

@testable import Conteur

/// The chain a real retelling takes, end to end, with the model stubbed:
/// transcript → comparison → diagnosis → feedback.
///
/// These are the invariants that must hold for *any* retelling, not the behaviour of one
/// rule. Each of them has been broken at least once.
struct FeedbackFlowTests {
    private let diagnosing = RuleBasedDiagnosis()
    private let composing = OnDeviceComposer()

    @Test func aRetellingWithAProblemGetsFeedbackThatPointsSomewhere() async {
        let result = await run(Fixture.comparison(told: [1, 2, 3], conveyedStakes: false))

        #expect(result.feedback != nil)
        #expect(result.feedback?.note.isEmpty == false)
        #expect(result.feedback?.challenge.isEmpty == false)
        #expect(result.feedback?.evidence.isEmpty == false)
    }

    /// A retelling with nothing wrong used to produce no feedback at all — which meant a
    /// blank screen and no way back into the loop.
    @Test func aRetellingWithNothingWrongStillGetsANoteAndAChallenge() async {
        let result = await run(Fixture.faithful)

        #expect(result.diagnosis.focus == nil)
        #expect(result.feedback != nil)
        #expect(result.feedback?.note.isEmpty == false)
        #expect(result.feedback?.challenge.isEmpty == false)
    }

    /// Every retelling long enough to analyse must offer a next attempt, whatever the
    /// diagnosis said.
    @Test func everyJudgeableRetellingOffersAChallenge() async {
        let shapes: [(String, SourceComparison)] = [
            ("faithful", Fixture.faithful),
            ("partial", Fixture.comparison(told: [1, 2])),
            ("scrambled", Fixture.comparison(told: [1, 5, 2, 6, 3])),
            ("invented", Fixture.comparison(told: Fixture.story.beats.map(\.id), inventing: ["Alex"])),
        ]

        for (name, comparison) in shapes {
            let result = await run(comparison)
            #expect(result.feedback?.challenge.isEmpty == false, "no challenge for \(name)")
        }
    }

    /// Half the dimensions used to be unjudgeable on a short retelling, because coverage
    /// depended on how many chunks the transcript happened to produce.
    @Test func aShortRetellingIsStillJudgeable() async {
        let result = await run(Fixture.faithful, transcript: Fixture.transcript(words: 60))

        #expect(result.diagnosis.isJudgeable)
        #expect(result.diagnosis.assessment(for: .coherence)?.band != .insufficient)
        #expect(result.diagnosis.assessment(for: .fidelity)?.band != .insufficient)
    }

    @Test func aRetellingTooShortToAnalyseSaysNothingRatherThanGuessing() async {
        let result = await run(
            Fixture.comparison(told: []),
            transcript: Fixture.transcript(words: 2)
        )

        #expect(result.diagnosis.isJudgeable == false)
        #expect(result.feedback == nil)
    }

    /// Feedback must never point at a moment that is not in the recording.
    /// An absence cannot be pointed at, so it must not carry a timestamp — a 0:00 beside
    /// "you left this out" reads as a claim that it happened at the start.
    @Test func anAbsenceCarriesNoTimestamp() async {
        let result = await run(Fixture.comparison(told: [1, 2, 3]))
        let absences = (result.feedback?.evidence ?? []).filter { !$0.isLocated }

        #expect(absences.isEmpty == false)
        #expect(absences.allSatisfy { $0.at == nil })
    }

    @Test func everyPieceOfEvidenceLandsInsideTheRetelling() async {
        let transcript = Fixture.transcript(words: 150)
        let result = await run(
            Fixture.comparison(told: [1, 5, 2], conveyedStakes: false),
            transcript: transcript
        )

        for evidence in result.feedback?.evidence ?? [] {
            // An absence has no location, and asserting one used to be satisfied by a
            // fabricated 0:00 that the feedback screen then displayed as a real moment.
            guard let at = evidence.at else { continue }
            #expect(at >= 0)
            #expect(at <= transcript.duration)
        }
    }

    /// Whatever the first telling looked like, a second one has to yield a verdict —
    /// including when the first had nothing wrong and the challenge was a stretch.
    @Test func aSecondTellingAlwaysProducesAVerdict() async {
        let shapes: [(String, SourceComparison)] = [
            ("faithful", Fixture.faithful),
            ("partial", Fixture.comparison(told: [1, 2])),
            ("invented", Fixture.comparison(told: Fixture.story.beats.map(\.id), inventing: ["Alex"])),
        ]

        for (name, comparison) in shapes {
            let first = await run(comparison)
            let second = await run(Fixture.faithful)

            let progress = RetellingComparison().compare(
                first.diagnosis,
                with: second.diagnosis,
                challenge: first.feedback?.challenge ?? ""
            )

            #expect(progress != nil, "no verdict after a \(name) first telling")
        }
    }

    // MARK: - The chain

    private struct Result {
        let diagnosis: Diagnosis
        let feedback: Feedback?
    }

    private func run(
        _ comparison: SourceComparison,
        transcript: Transcript? = nil
    ) async -> Result {
        let diagnosis = diagnosing.diagnose(
            Fixture.input(comparison, transcript: transcript),
            against: .none
        )
        let feedback = await composing.compose(from: diagnosis, history: nil, progress: nil)
        return Result(diagnosis: diagnosis, feedback: feedback)
    }
}
