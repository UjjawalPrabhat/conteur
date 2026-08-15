import Foundation
import Testing

@testable import Conteur

/// The chain a real retelling takes, end to end, with the model stubbed:
/// transcript → chunks → beats → diagnosis → feedback.
///
/// These are the invariants that must hold for *any* retelling, not the behaviour of one
/// rule. Each of them has been broken at least once.
struct FeedbackFlowTests {
    private let chunker = TranscriptChunker()
    private let diagnosing = RuleBasedDiagnosis()
    private let composing = OnDeviceComposer()

    @Test func aRetellingWithAProblemGetsFeedbackThatPointsSomewhere() async {
        let result = await run(transcript(seconds: 90), beats: .withDroppedThread)

        #expect(result.feedback != nil)
        #expect(result.feedback?.note.isEmpty == false)
        #expect(result.feedback?.challenge.isEmpty == false)
        #expect(result.feedback?.evidence.isEmpty == false)
    }

    /// A retelling with nothing wrong used to produce no feedback at all — which meant a
    /// blank screen and no way back into the loop.
    @Test func aRetellingWithNothingWrongStillGetsANoteAndAChallenge() async {
        let result = await run(transcript(seconds: 90), beats: .clean)

        #expect(result.diagnosis.focus == nil)
        #expect(result.feedback != nil)
        #expect(result.feedback?.note.isEmpty == false)
        #expect(result.feedback?.challenge.isEmpty == false)
    }

    /// Every retelling long enough to analyse must offer a next attempt, whatever the
    /// diagnosis said.
    @Test func everyJudgeableRetellingOffersAChallenge() async {
        for beats in [FakeNarrative.withDroppedThread, .clean, .padded] {
            let result = await run(transcript(seconds: 90), beats: beats)
            #expect(result.feedback?.challenge.isEmpty == false, "no challenge for \(beats)")
        }
    }

    /// Chunks used to be a minute long, so anything under two minutes produced one beat
    /// and half the dimensions could never be judged.
    @Test func aShortRetellingIsStillJudgeable() async {
        let result = await run(transcript(seconds: 60), beats: .clean)

        #expect(result.beats.count >= 2)
        #expect(result.diagnosis.isJudgeable)
        #expect(result.diagnosis.assessment(for: .coherence)?.band != .insufficient)
    }

    @Test func aRetellingTooShortToAnalyseSaysNothingRatherThanGuessing() async {
        let result = await run(transcript(seconds: 3), beats: .clean)

        #expect(result.beats.isEmpty)
        #expect(result.feedback == nil)
    }

    /// Feedback must never point at a moment that is not in the recording.
    @Test func everyPieceOfEvidenceLandsInsideTheRetelling() async {
        let source = transcript(seconds: 90)
        let result = await run(source, beats: .withDroppedThread)

        for evidence in result.feedback?.evidence ?? [] {
            #expect(evidence.at >= 0)
            #expect(evidence.at <= source.duration)
        }
    }

    /// Whatever the first telling looked like, a second one has to yield a verdict —
    /// including when the first had nothing wrong and the challenge was a stretch.
    @Test func aSecondTellingAlwaysProducesAVerdict() async {
        for shape in [FakeNarrative.withDroppedThread, .clean, .padded] {
            let first = await run(transcript(seconds: 90), beats: shape)
            let second = await run(transcript(seconds: 90), beats: .clean)

            let progress = RetellingComparison().compare(
                first.diagnosis,
                with: second.diagnosis,
                challenge: first.feedback?.challenge ?? ""
            )

            #expect(progress != nil, "no verdict after a \(shape) first telling")
        }
    }

    // MARK: - The chain

    private struct Result {
        let beats: [Beat]
        let diagnosis: Diagnosis
        let feedback: Feedback?
    }

    private func run(_ transcript: Transcript, beats shape: FakeNarrative) async -> Result {
        let narrative = FakeNarrativeAnalyzer(shape: shape)
        let chunks = chunker.chunks(of: transcript)
        var beats: [Beat] = []
        for chunk in chunks {
            beats.append(await narrative.label(chunk, index: beats.count))
        }

        let reading = NarrativeReading(beats: beats, arc: narrative.arc(from: beats))
        let timeline = FeatureTimeline(
            transcript: transcript,
            delivery: DeliveryAnalyzer().analyze(transcript),
            prosody: [],
            expressivity: []
        )
        let diagnosis = diagnosing.diagnose(
            DiagnosticInput(timeline: timeline, narrative: reading),
            against: .none
        )
        let feedback = await composing.compose(from: diagnosis, history: nil, progress: nil)

        return Result(beats: beats, diagnosis: diagnosis, feedback: feedback)
    }

    private func transcript(seconds: TimeInterval) -> Transcript {
        let spacing = 0.4
        let count = Int(seconds / spacing)
        return Transcript(
            words: (0..<count).map { index in
                let start = Double(index) * spacing
                return SpokenWord(text: "word\(index)", start: start, end: start + 0.2)
            }
        )
    }
}

private enum FakeNarrative {
    case clean
    case withDroppedThread
    case padded
}

/// Stands in for the on-device model so the chain around it can be exercised.
private struct FakeNarrativeAnalyzer {
    let shape: FakeNarrative

    func label(_ chunk: TranscriptChunk, index: Int) async -> Beat {
        Beat(
            start: chunk.start,
            end: chunk.end,
            summary: "stretch \(index)",
            kind: shape == .padded && index > 0 ? .lowValue : .corePlot,
            entitiesIntroduced: shape == .withDroppedThread && index == 0 ? ["brother"] : [],
            entitiesReferenced: index > 0 ? ["protagonist"] : [],
            statesStakes: shape != .withDroppedThread,
            connectsCausally: shape != .withDroppedThread
        )
    }

    func arc(from beats: [Beat]) -> NarrativeArc {
        NarrativeArc(
            shape: .thematic,
            present: Set(StoryComponent.allCases),
            climaxBeat: beats.isEmpty ? nil : 0,
            sequencingIsFollowable: true
        )
    }
}
