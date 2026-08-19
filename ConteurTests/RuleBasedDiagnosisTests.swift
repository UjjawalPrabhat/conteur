import Foundation
import Testing

@testable import Conteur

struct RuleBasedDiagnosisTests {
    private let diagnosis = RuleBasedDiagnosis()

    // MARK: - Saying nothing

    @Test func nothingIsDiagnosedWithoutARetelling() {
        let empty = DiagnosticInput.nothing(for: Fixture.story)

        #expect(diagnosis.diagnose(empty, against: .none).focus == nil)
    }

    /// A two-word retelling used to report strong across every dimension, because no rule
    /// could fire and nothing firing was scored as nothing wrong.
    @Test func tooLittleToJudgeIsNotReportedAsStrong() {
        let input = Fixture.input(
            Fixture.comparison(told: []),
            transcript: Fixture.transcript(words: 2)
        )

        let result = diagnosis.diagnose(input, against: .none)

        #expect(result.assessments.allSatisfy { $0.band == .insufficient })
        #expect(result.focus == nil)
    }

    /// The flagged weakness cannot also be described as strong.
    @Test func aDimensionWithAFindingIsNeverStrong() {
        let input = Fixture.input(Fixture.comparison(told: [1, 2], mentioning: ["Aren"]))

        let coherence = diagnosis.diagnose(input, against: .none).assessment(for: .coherence)

        #expect(coherence?.findings.isEmpty == false)
        #expect(coherence?.band != .strong)
    }

    // MARK: - What the story makes measurable

    @Test func anEventTheStoryTurnedOnAndTheyLeftOutIsFound() {
        let input = Fixture.input(Fixture.comparison(told: [1, 2, 3]))

        let structure = diagnosis.diagnose(input, against: .none).assessment(for: .structure)

        #expect(structure?.findings.isEmpty == false)
        #expect(structure?.findings.contains { $0.subject == "omitted-7" } == true)
    }

    @Test func tellingTheWholeStoryLeavesStructureAlone() {
        let input = Fixture.input(Fixture.faithful)

        #expect(diagnosis.diagnose(input, against: .none).assessment(for: .structure)?.findings.isEmpty == true)
    }

    @Test func aCentralCharacterNeverMentionedIsFound() {
        let input = Fixture.input(
            Fixture.comparison(told: Fixture.story.beats.map(\.id), mentioning: ["Aren"])
        )

        let coherence = diagnosis.diagnose(input, against: .none).assessment(for: .coherence)

        #expect(coherence?.findings.contains { $0.subject == "missing-the silver fish" } == true)
    }

    @Test func eventsToldOutOfOrderAreFound() {
        let input = Fixture.input(Fixture.comparison(told: [1, 5, 2, 6, 3]))

        let coherence = diagnosis.diagnose(input, against: .none).assessment(for: .coherence)

        #expect(coherence?.findings.contains { $0.subject == "order" } == true)
    }

    @Test func tellingEventsInTheStorysOrderIsNotFlagged() {
        let input = Fixture.input(Fixture.faithful)

        #expect(diagnosis.diagnose(input, against: .none).assessment(for: .coherence)?.findings.isEmpty == true)
    }

    /// The story authored the causal link, so no judgement is needed about whether the
    /// retelling *felt* connected — the effect was told and its cause was not.
    @Test func anEffectToldWithoutItsCauseIsFound() {
        let input = Fixture.input(Fixture.comparison(told: [1, 2, 3, 6]))

        let coherence = diagnosis.diagnose(input, against: .none).assessment(for: .coherence)

        #expect(coherence?.findings.contains { $0.subject == "uncaused-6" } == true)
    }

    @Test func notConveyingWhyItMatteredIsFound() {
        let input = Fixture.input(
            Fixture.comparison(told: Fixture.story.beats.map(\.id), conveyedStakes: false)
        )

        let engagement = diagnosis.diagnose(input, against: .none).assessment(for: .engagement)

        #expect(engagement?.findings.contains { $0.subject == "stakes" } == true)
    }

    // MARK: - Fidelity

    @Test func aCharacterTheStoryNeverHadIsAFidelityFinding() {
        let input = Fixture.input(
            Fixture.comparison(told: Fixture.story.beats.map(\.id), inventing: ["Alex", "Jordan"])
        )

        let fidelity = diagnosis.diagnose(input, against: .none).assessment(for: .fidelity)

        #expect(fidelity?.findings.contains { $0.subject == "invented-names" } == true)
        #expect(fidelity?.band != .strong)
    }

    @Test func losingMostOfTheStoryIsAFidelityFinding() {
        let input = Fixture.input(Fixture.comparison(told: [1, 2]))

        let fidelity = diagnosis.diagnose(input, against: .none).assessment(for: .fidelity)

        #expect(fidelity?.findings.contains { $0.subject == "coverage" } == true)
    }

    @Test func tellingItFaithfullyLeavesFidelityAlone() {
        #expect(
            diagnosis.diagnose(Fixture.input(Fixture.faithful), against: .none)
                .assessment(for: .fidelity)?.findings.isEmpty == true
        )
    }

    // MARK: - Length

    @Test func aRetellingReducedToASummaryIsFlagged() {
        let input = Fixture.input(
            Fixture.comparison(told: Fixture.story.beats.map(\.id), compression: 0.1),
            transcript: Fixture.transcript(words: 40)
        )

        let relevance = diagnosis.diagnose(input, against: .none).assessment(for: .relevance)

        #expect(relevance?.findings.contains { $0.subject == "skeletal" } == true)
    }

    @Test func aRetellingLongerThanTheStoryIsFlagged() {
        let input = Fixture.input(
            Fixture.comparison(told: Fixture.story.beats.map(\.id), compression: 1.1)
        )

        let relevance = diagnosis.diagnose(input, against: .none).assessment(for: .relevance)

        #expect(relevance?.findings.contains { $0.subject == "padded" } == true)
    }

    @Test func aRetellingOfTheExpectedLengthIsNotFlagged() {
        #expect(
            diagnosis.diagnose(Fixture.input(Fixture.faithful), against: .none)
                .assessment(for: .relevance)?.findings.isEmpty == true
        )
    }

    // MARK: - Delivery

    @Test func fillersAreJudgedAgainstWordCountNotCounted() {
        let sparse = Fixture.input(Fixture.faithful, transcript: Fixture.transcript(words: 120, fillers: 2))
        let dense = Fixture.input(Fixture.faithful, transcript: Fixture.transcript(words: 120, fillers: 12))

        #expect(diagnosis.diagnose(sparse, against: .none).assessment(for: .delivery)?.findings.isEmpty == true)
        #expect(diagnosis.diagnose(dense, against: .none).assessment(for: .delivery)?.findings.isEmpty == false)
    }

    // MARK: - Focus

    /// Getting the story wrong outranks telling it inelegantly.
    @Test func focusIsTheWeaknessThatMattersMost() {
        let input = Fixture.input(
            Fixture.comparison(told: Fixture.story.beats.map(\.id), inventing: ["Alex"]),
            transcript: Fixture.transcript(words: 120, fillers: 12)
        )

        #expect(diagnosis.diagnose(input, against: .none).focus?.dimension == .fidelity)
    }

    @Test func focusIsRelativeToWhatThisSpeakerUsuallyDoes() {
        let input = Fixture.input(
            Fixture.comparison(told: Fixture.story.beats.map(\.id), inventing: ["Alex"]),
            transcript: Fixture.transcript(words: 120, fillers: 12)
        )
        // Somebody who always invents, and does not usually stumble.
        let baseline = Baseline(scores: [.fidelity: 0.65, .delivery: 0.95])

        #expect(diagnosis.diagnose(input, against: baseline).focus?.dimension == .delivery)
    }

    @Test func theSameRetellingAlwaysDiagnosesIdentically() {
        let input = Fixture.input(
            Fixture.comparison(told: [1, 5, 2], inventing: ["Alex"], conveyedStakes: false),
            transcript: Fixture.transcript(words: 120, fillers: 12)
        )

        let runs = (0..<5).map { _ in diagnosis.diagnose(input, against: .none) }

        #expect(Set(runs.map(\.focus?.dimension)).count == 1)
        #expect(Set(runs.map { $0.assessments.map(\.band) }).count == 1)
    }
}
