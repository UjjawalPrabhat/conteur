import Foundation

/// Where in the retelling a canonical beat was covered.
struct BeatCoverage: Sendable, Hashable {
    let beat: CanonicalBeat
    let quote: String
    let at: TimeInterval
}

/// A retelling measured against the story it came from.
///
/// This is what ground truth buys. Nothing here is inferred from the retelling alone —
/// every field is a comparison against something authored, which is why most of it can be
/// computed rather than judged.
struct SourceComparison: Sendable {
    let story: GuidedStory
    let covered: [BeatCoverage]
    let omitted: [CanonicalBeat]
    let mentionedEntities: [StoryEntity]
    let omittedEntities: [StoryEntity]
    /// Names spoken that appear nowhere in the story's cast. The clearest fidelity signal
    /// there is: a reteller who introduces a character the story never had.
    let inventedNames: [String]
    /// Fraction of covered beat pairs told in the story's own order, 0...1.
    let orderAccuracy: Double
    /// Retelling length as a fraction of the story's.
    let compression: Double
    let conveyedStakes: Bool

    static func nothing(for story: GuidedStory) -> SourceComparison {
        SourceComparison(
            story: story,
            covered: [],
            omitted: story.beats,
            mentionedEntities: [],
            omittedEntities: story.cast,
            inventedNames: [],
            orderAccuracy: 0,
            compression: 0,
            conveyedStakes: false
        )
    }
}

extension SourceComparison {
    var omittedLoadBearing: [CanonicalBeat] {
        omitted.filter(\.loadBearing)
    }

    var omittedCentralCast: [StoryEntity] {
        omittedEntities.filter { $0.importance == .central }
    }

    /// Components of the story that never came through, limited to those the story
    /// actually contained.
    var omittedComponents: Set<StoryComponent> {
        Set(omittedLoadBearing.map(\.component)).subtracting(covered.map(\.beat.component))
    }

    var coverageShare: Double {
        guard !story.loadBearingBeats.isEmpty else { return 1 }
        let hit = covered.filter(\.beat.loadBearing).count
        return Double(hit) / Double(story.loadBearingBeats.count)
    }

    /// Whether the retelling ran shorter or longer than immediate recall of a story this
    /// length would be expected to.
    var isSkeletal: Bool {
        compression > 0 && compression < GuidedStory.recallRatio.lowerBound * 0.6
    }

    var isPadded: Bool {
        compression > GuidedStory.recallRatio.upperBound * 1.6
    }

    var climaxCoverage: BeatCoverage? {
        covered.first { $0.beat.isClimax }
    }

    /// When a covered beat was told, from the moment it was mentioned to the moment the
    /// next one was. Used to check pace and expression at the point that mattered.
    func span(of coverage: BeatCoverage, endingBy end: TimeInterval) -> Range<TimeInterval> {
        let next = covered.first { $0.at > coverage.at }?.at ?? end
        return coverage.at..<max(coverage.at + 0.5, next)
    }

    /// Events told without the event that caused them — the listener got an effect with no
    /// cause, which is a coherence failure the story itself rules on.
    var uncausedEvents: [(told: CanonicalBeat, missingCause: CanonicalBeat)] {
        let told = Set(covered.map(\.beat.id))
        return covered.compactMap { coverage in
            guard
                let causeID = coverage.beat.causedBy,
                !told.contains(causeID),
                let cause = story.beat(causeID)
            else { return nil }
            return (coverage.beat, cause)
        }
    }

    /// Causal links the story had between two beats the reteller covered — if both ends
    /// were told, the link between them was tellable.
    var tellableCausalLinks: [(cause: CanonicalBeat, effect: CanonicalBeat)] {
        let told = Set(covered.map(\.beat.id))
        return story.beats.compactMap { beat in
            guard
                let causeID = beat.causedBy,
                told.contains(beat.id), told.contains(causeID),
                let cause = story.beat(causeID)
            else { return nil }
            return (cause, beat)
        }
    }
}
