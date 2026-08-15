import Foundation
import Testing

@testable import Conteur

struct RuleBasedDiagnosisTests {
    private let diagnosis = RuleBasedDiagnosis()

    @Test func nothingIsDiagnosedWithoutARetelling() {
        #expect(diagnosis.diagnose(.empty, against: .none).focus == nil)
    }

    /// A two-word retelling used to report strong across every dimension, because no
    /// rule could fire and nothing firing was scored as nothing wrong.
    @Test func tooLittleToJudgeIsNotReportedAsStrong() {
        let barelyAnything = DiagnosticInput(
            timeline: FeatureTimeline(
                transcript: filled(words: 2, fillers: 0),
                delivery: DeliveryAnalyzer().analyze(filled(words: 2, fillers: 0)),
                prosody: [],
                expressivity: []
            ),
            narrative: .empty
        )

        let result = diagnosis.diagnose(barelyAnything, against: .none)

        #expect(result.assessments.allSatisfy { $0.band == .insufficient })
        #expect(result.focus == nil)
    }

    /// A dimension speaks when at least one of its rules had something to look at, and
    /// stays quiet otherwise — the prerequisite belongs to each rule, not to the
    /// dimension as a whole.
    @Test func aDimensionSpeaksOnlyWhenOneOfItsRulesCouldLook() {
        let oneBeat = input(beats: [beat(0, 30, .corePlot, statesStakes: true)])

        let result = diagnosis.diagnose(oneBeat, against: .none)

        // Nothing about engagement is available here: stakes needs two core beats, pitch
        // needs voiced audio, and expression needs a located climax.
        #expect(result.assessment(for: .engagement)?.band == .insufficient)
        // Structure and sequencing can both be read from a single beat.
        #expect(result.assessment(for: .structure)?.band != .insufficient)
        #expect(result.assessment(for: .coherence)?.band != .insufficient)
    }

    /// The flagged weakness cannot also be described as strong.
    @Test func aDimensionWithAFindingIsNeverStrong() {
        let input = input(
            beats: [
                beat(0, 30, .corePlot, introduces: ["brother"], statesStakes: true),
                beat(30, 60, .corePlot, references: ["protagonist"], connectsCausally: true),
            ]
        )

        let coherence = diagnosis.diagnose(input, against: .none).assessment(for: .coherence)

        #expect(coherence?.findings.isEmpty == false)
        #expect(coherence?.band != .strong)
    }

    @Test func introducingSomethingAndNeverReturningToItIsFound() {
        let input = input(beats: [
            beat(0, 30, .corePlot, introduces: ["brother"]),
            beat(30, 60, .corePlot, references: ["protagonist"]),
        ])

        let coherence = diagnosis.diagnose(input, against: .none).assessment(for: .coherence)

        #expect(coherence?.findings.count == 1)
        #expect(coherence?.findings.first?.observation.contains("brother") == true)
        #expect(coherence?.findings.first?.evidence.first?.at == 0)
    }

    @Test func aThreadPickedUpLaterIsNotAFinding() {
        let input = input(beats: [
            beat(0, 30, .corePlot, introduces: ["brother"]),
            beat(30, 60, .corePlot, references: ["brother"]),
        ])

        #expect(diagnosis.diagnose(input, against: .none).assessment(for: .coherence)?.findings.isEmpty == true)
    }

    @Test func timeSpentOnInconsequentialDetailSurfacesRelevance() {
        let input = input(beats: [
            beat(0, 20, .corePlot),
            beat(20, 120, .lowValue),
        ])

        let relevance = diagnosis.diagnose(input, against: .none).assessment(for: .relevance)

        #expect(relevance?.findings.count == 1)
        #expect(relevance?.findings.first?.evidence.first?.measure == "100s")
    }

    @Test func aLittleColourIsNotPadding() {
        let input = input(beats: [
            beat(0, 100, .corePlot),
            beat(100, 110, .lowValue),
        ])

        #expect(diagnosis.diagnose(input, against: .none).assessment(for: .relevance)?.findings.isEmpty == true)
    }

    @Test func structuralExpectationsFollowTheShapeOfTheStory() {
        let beats = [beat(0, 30, .corePlot), beat(30, 60, .emotional)]
        let present: Set<StoryComponent> = [.setting, .conflict, .consequences]

        let thematic = diagnosis.diagnose(
            input(beats: beats, shape: .thematic, present: present),
            against: .none
        )
        let plotDriven = diagnosis.diagnose(
            input(beats: beats, shape: .plotDriven, present: present),
            against: .none
        )

        // The same missing resolution is expected of one shape and not the other.
        #expect(thematic.assessment(for: .structure)?.findings.isEmpty == true)
        #expect(plotDriven.assessment(for: .structure)?.findings.isEmpty == false)
    }

    @Test func recountingEventsWithoutStakesSurfacesEngagement() {
        let input = input(beats: [
            beat(0, 30, .corePlot),
            beat(30, 60, .corePlot),
        ])

        #expect(diagnosis.diagnose(input, against: .none).assessment(for: .engagement)?.findings.isEmpty == false)
    }

    @Test func fillersAreJudgedAgainstWordCountNotCounted() {
        let sparse = input(beats: [beat(0, 60, .corePlot, statesStakes: true)], transcript: filled(words: 100, fillers: 2))
        let dense = input(beats: [beat(0, 60, .corePlot, statesStakes: true)], transcript: filled(words: 100, fillers: 8))

        #expect(diagnosis.diagnose(sparse, against: .none).assessment(for: .delivery)?.findings.isEmpty == true)
        #expect(diagnosis.diagnose(dense, against: .none).assessment(for: .delivery)?.findings.isEmpty == false)
    }

    @Test func focusIsTheWeaknessThatMattersMost() {
        let input = input(
            beats: [
                beat(0, 30, .corePlot, introduces: ["brother"], statesStakes: true),
                beat(30, 60, .corePlot, references: ["protagonist"], connectsCausally: true),
            ],
            transcript: filled(words: 100, fillers: 8)
        )

        let focus = diagnosis.diagnose(input, against: .none).focus

        // Both coherence and delivery fired; a story that cannot be followed outranks
        // one with fillers in it.
        #expect(focus?.dimension == .coherence)
    }

    @Test func focusIsRelativeToWhatThisSpeakerUsuallyDoes() {
        let input = input(
            beats: [
                beat(0, 30, .corePlot, introduces: ["brother"], statesStakes: true),
                beat(30, 60, .corePlot, references: ["protagonist"], connectsCausally: true),
            ],
            transcript: filled(words: 100, fillers: 8)
        )
        let baseline = Baseline(scores: [.coherence: 0.7, .delivery: 0.95])

        let focus = diagnosis.diagnose(input, against: baseline).focus

        // Coherence sits where it always does for this speaker; the delivery slip is
        // the thing that actually changed.
        #expect(focus?.dimension == .delivery)
    }

    @Test func theSameRetellingAlwaysDiagnosesIdentically() {
        let input = input(
            beats: [
                beat(0, 30, .corePlot, introduces: ["brother"]),
                beat(30, 130, .lowValue),
            ],
            transcript: filled(words: 100, fillers: 8)
        )

        let runs = (0..<5).map { _ in diagnosis.diagnose(input, against: .none) }
        let focuses = runs.map(\.focus?.dimension)
        let bands = runs.map { $0.assessments.map(\.band) }

        #expect(Set(focuses).count == 1)
        #expect(Set(bands).count == 1)
    }

    // MARK: - Fixtures

    private func beat(
        _ start: TimeInterval,
        _ end: TimeInterval,
        _ kind: SpanKind,
        introduces: [String] = [],
        references: [String] = [],
        statesStakes: Bool = false,
        connectsCausally: Bool = false
    ) -> Beat {
        Beat(
            start: start,
            end: end,
            summary: "beat at \(start)",
            kind: kind,
            entitiesIntroduced: introduces,
            entitiesReferenced: references,
            statesStakes: statesStakes,
            connectsCausally: connectsCausally
        )
    }

    private func input(
        beats: [Beat],
        shape: StoryShape = .thematic,
        present: Set<StoryComponent> = Set(StoryComponent.allCases),
        transcript: Transcript? = nil
    ) -> DiagnosticInput {
        let transcript = transcript ?? filled(words: 20, fillers: 0)
        return DiagnosticInput(
            timeline: FeatureTimeline(
                transcript: transcript,
                delivery: DeliveryAnalyzer().analyze(transcript),
                prosody: [],
                expressivity: []
            ),
            narrative: NarrativeReading(
                beats: beats,
                arc: NarrativeArc(
                    shape: shape,
                    present: present,
                    climaxBeat: nil,
                    sequencingIsFollowable: true
                )
            )
        )
    }

    /// A transcript of a given length with a given number of filled pauses spread
    /// through it. Words are distinct because an all-identical transcript would trip
    /// the restart rule and obscure what a test is actually asserting.
    private func filled(words: Int, fillers: Int) -> Transcript {
        let positions = Set(
            stride(from: 0, to: words, by: max(1, words / max(fillers, 1))).prefix(fillers)
        )
        let spoken = (0..<words).map { index in
            let start = Double(index) * 0.4
            return SpokenWord(
                text: positions.contains(index) ? "um" : "word\(index)",
                start: start,
                end: start + 0.2
            )
        }
        return Transcript(words: spoken)
    }
}
