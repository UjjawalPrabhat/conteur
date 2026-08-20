import Foundation
import Testing

@testable import Conteur

/// The model cannot run here, so what is tested is the scoring — that a good run reads as
/// good, a bad one reads as bad, and the two failure directions are told apart.
struct ComparisonEvaluatorTests {
    @Test func agreeingExactlyScoresPerfectly() async {
        let summary = await evaluate(.agreeing)

        #expect(summary.precision == 1)
        #expect(summary.recall == 1)
        #expect(summary.totalFalsePositives == 0)
        #expect(summary.totalFalseNegatives == 0)
    }

    /// The dangerous direction: crediting the speaker with events they never told.
    @Test func creditingUntoldEventsShowsAsLostPrecision() async {
        let summary = await evaluate(.overclaiming)

        #expect(summary.precision < 1)
        #expect(summary.recall == 1)
        #expect(summary.totalFalsePositives > 0)
    }

    /// The other direction: telling somebody they left out what they said.
    @Test func missingToldEventsShowsAsLostRecall() async {
        let summary = await evaluate(.underclaiming)

        #expect(summary.recall < 1)
        #expect(summary.totalFalseNegatives > 0)
    }

    /// Coverage can be right while the feedback still cannot point anywhere.
    @Test func unquotableCoverageShowsAsLowQuoteYield() async {
        let summary = await evaluate(.unquotable)

        #expect(summary.recall == 1)
        #expect(summary.quoteYield == 0)
    }

    @Test func aThrownComparisonIsRecordedRatherThanScoredAsZero() async {
        let summary = await evaluate(.failing)

        #expect(summary.failures.count == summary.scores.count)
        #expect(summary.answered.isEmpty)
    }

    /// A refusal says nothing about the model's judgement. Averaging refusals in as zero was
    /// what made a run where six of fifteen were refused look like 36% accuracy.
    @Test func refusalsAreExcludedFromTheAverages() async {
        let refusing = await evaluate(.failing)

        #expect(refusing.precision == 0)
        #expect(refusing.answered.isEmpty)
    }

    @Test func commentarySamplesExpectNoCoverage() {
        let commentary = RetellingCorpus.all.filter { $0.shape == .commentary }

        #expect(!commentary.isEmpty)
        #expect(commentary.allSatisfy { $0.expectedBeats.isEmpty })
    }

    /// Only the faithful retellings state the point of the story, so stakes accuracy is
    /// measuring something rather than always agreeing.
    @Test func onlyFaithfulSamplesExpectStakes() {
        let expecting = RetellingCorpus.all.filter(\.expectedStakes)

        #expect(!expecting.isEmpty)
        #expect(expecting.allSatisfy { $0.shape == .faithful })
    }

    /// The pattern match this replaced tested an Optional and never fired, which is how nine
    /// consecutive refusals were reported as zero refusals.
    /// Three different reasons a call produces nothing, and they call for different
    /// responses. Being unable to tell them apart made two evaluation runs unreadable.
    @Test func theReasonsACallProducedNothingAreToldApart() {
        struct Refused: Error, LocalizedError {
            var errorDescription: String? { "Detected content likely to be unsafe" }
        }
        struct Filled: Error, LocalizedError {
            var errorDescription: String? { "Exceeded model context window size" }
        }
        struct Broken: Error {}

        #expect(ModelFailure(Refused()) == .refused)
        #expect(ModelFailure(Filled()) == .contextExceeded)
        #expect(ModelFailure(Broken()) == .other)
        #expect(Refused().isGuardrailRefusal)
        #expect(Broken().isGuardrailRefusal == false)
    }

    @Test func everySampleNamesAStoryThatExists() {
        #expect(RetellingCorpus.all.allSatisfy { $0.story != nil })
    }

    /// Expected coverage cannot reference a beat the story does not have.
    @Test func expectedBeatsExistInTheirStory() {
        for sample in RetellingCorpus.all {
            guard let story = sample.story else { continue }
            let ids = Set(story.beats.map(\.id))
            #expect(sample.expectedBeats.isSubset(of: ids), "\(sample.id) expects beats outside the story")
        }
    }

    @Test func samplesAreLongEnoughToAnalyse() {
        for sample in RetellingCorpus.all {
            #expect(sample.transcript.words.count >= 40, "\(sample.id) is too short to reach analysis")
        }
    }

    private func evaluate(_ behaviour: StubComparer.Behaviour) async -> EvaluationSummary {
        await ComparisonEvaluator(comparer: StubComparer(behaviour: behaviour))
            .evaluate(RetellingCorpus.thirdCast.filter { $0.shape != .commentary })
    }
}

/// Stands in for the on-device model with each of the ways it can be wrong.
private struct StubComparer: SourceComparing {
    enum Behaviour {
        case agreeing
        case overclaiming
        case underclaiming
        case unquotable
        case failing
    }

    struct Failure: Error, LocalizedError {
        var errorDescription: String? { "stub refused" }
    }

    let behaviour: Behaviour

    func compare(_ transcript: Transcript, with story: GuidedStory) async throws -> SourceComparison {
        if case .failing = behaviour { throw Failure() }

        let expected = RetellingCorpus.all
            .first { $0.transcript.words.count == transcript.words.count }?
            .expectedBeats ?? []

        let reported: Set<Int>
        switch behaviour {
        case .agreeing, .unquotable: reported = expected
        case .overclaiming: reported = expected.union(story.beats.map(\.id))
        case .underclaiming: reported = Set(expected.sorted().dropLast())
        case .failing: reported = []
        }

        let located = behaviour == .unquotable ? Set<Int>() : reported
        let covered = reported.sorted().enumerated().compactMap { index, id -> BeatCoverage? in
            guard let beat = story.beat(id) else { return nil }
            return located.contains(id)
                ? BeatCoverage(beat: beat, quote: "quote", at: Double(index))
                : BeatCoverage(beat: beat, quote: nil, at: nil)
        }

        return SourceComparison(
            story: story,
            covered: covered,
            omitted: story.beats.filter { !reported.contains($0.id) },
            mentionedEntities: story.cast,
            omittedEntities: [],
            inventedNames: [],
            orderAccuracy: 1,
            compression: 0.4,
            conveyedStakes: false
        )
    }
}
