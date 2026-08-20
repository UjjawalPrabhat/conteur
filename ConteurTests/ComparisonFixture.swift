import Foundation

@testable import Conteur

/// Builds a comparison directly, so the rules can be exercised without a model.
///
/// This is the payoff of ground truth for testing too: a fixture is now "they told beats 1,
/// 2 and 5, left out Mira, and invented somebody" — which is legible, where a fake narrative
/// analyser was a pile of inferred flags.
enum Fixture {
    static let story = StoryLibrary.thirdCast

    static func transcript(
        words: Int,
        fillers: Int = 0,
        spacing: TimeInterval = 0.4,
        stalls: Int = 0
    ) -> Transcript {
        let fillerPositions = Set(
            stride(from: 0, to: words, by: max(1, words / max(fillers, 1))).prefix(fillers)
        )
        var time = 0.0
        var spoken: [SpokenWord] = []
        for index in 0..<words {
            // Stalls are inserted as long gaps early on, where they are easy to assert.
            if index > 0, index <= stalls { time += 4 }
            let text = fillerPositions.contains(index) ? "um" : "word\(index)"
            spoken.append(SpokenWord(text: text, start: time, end: time + spacing / 2))
            time += spacing
        }
        return Transcript(words: spoken)
    }

    /// - Parameter told: beat ids in the order the reteller reached them.
    static func comparison(
        story: GuidedStory = Fixture.story,
        told: [Int],
        unlocated: Set<Int> = [],
        mentioning: [String]? = nil,
        inventing: [String] = [],
        conveyedStakes: Bool = true,
        compression: Double = 0.4
    ) -> SourceComparison {
        let covered = told.enumerated().compactMap { index, id -> BeatCoverage? in
            guard let beat = story.beat(id) else { return nil }
            guard !unlocated.contains(id) else {
                return BeatCoverage(beat: beat, quote: nil, at: nil)
            }
            return BeatCoverage(beat: beat, quote: "word\(index)", at: Double(index) * 3)
        }
        let coveredIDs = Set(covered.map(\.beat.id))

        // Default to every central character being mentioned, so a test that cares about an
        // omission has to say so.
        let names = Set(mentioning ?? story.centralCast.map(\.name))
        let mentioned = story.cast.filter { names.contains($0.name) }

        return SourceComparison(
            story: story,
            covered: covered,
            omitted: story.beats.filter { !coveredIDs.contains($0.id) },
            unresolved: [],
            mentionedEntities: mentioned,
            omittedEntities: story.cast.filter { !names.contains($0.name) },
            inventedNames: inventing.enumerated().map { InventedName(name: $1, at: Double($0)) },
            orderAccuracy: SourceMatcher().orderAccuracy(of: covered),
            compression: compression,
            conveyedStakes: conveyedStakes
        )
    }

    static func input(
        _ comparison: SourceComparison,
        transcript: Transcript? = nil
    ) -> DiagnosticInput {
        let transcript = transcript ?? Fixture.transcript(words: 120)
        return DiagnosticInput(
            timeline: FeatureTimeline(
                transcript: transcript,
                delivery: DeliveryAnalyzer().analyze(transcript),
                prosody: [],
                expressivity: []
            ),
            comparison: comparison
        )
    }

    /// Every beat, in order, nothing invented, stakes conveyed.
    static var faithful: SourceComparison {
        comparison(told: story.beats.map(\.id))
    }
}
