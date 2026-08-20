import Foundation

/// A canonical beat the retelling covered, and where — when that can be established.
///
/// The location is optional on purpose. The model is asked to copy the words that cover a
/// beat, and a small model often paraphrases instead. Its judgement that the beat *was*
/// covered is still usable; only the pointer into the recording is lost. Discarding the
/// whole coverage over an unquotable quote turned told beats into omissions.
struct BeatCoverage: Sendable, Hashable {
    let beat: CanonicalBeat
    let quote: String?
    let at: TimeInterval?

    var isLocated: Bool { at != nil }
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
    /// Events the model would not judge. Neither covered nor omitted: the guardrail refuses
    /// individual events unpredictably, and reporting one as an omission would blame the
    /// speaker for something they may well have told.
    let unresolved: [CanonicalBeat]
    let mentionedEntities: [StoryEntity]
    let omittedEntities: [StoryEntity]
    /// Names spoken that appear nowhere in the story's cast. The clearest fidelity signal
    /// there is: a reteller who introduces a character the story never had.
    let inventedNames: [InventedName]
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
            unresolved: [],
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

    /// Whether anything in the retelling was recognisably about this story. Entities match
    /// on plain text, so this holds even when no event was recognised.
    var recognisedSomething: Bool {
        !covered.isEmpty || !mentionedEntities.isEmpty
    }

    /// Whether nothing beyond the scene-setting came through.
    ///
    /// The model credits the setting beat on the strength of a character being named — it did
    /// so on every commentary sample in the corpus. Naming the people is not telling the
    /// story, so coverage consisting only of setting is not coverage.
    var narratedNothing: Bool {
        !covered.isEmpty && covered.allSatisfy { $0.beat.component == .setting }
    }

    /// They were talking about this story but told none of what happened in it.
    ///
    /// A real failure with a name — Labov's narrative clauses against free clauses. Somebody
    /// describing a story, guessing at it, or commenting on it is not narrating it, and
    /// because the cast was recognised this is a finding rather than an unknown.
    var talkedAroundIt: Bool {
        (covered.isEmpty || narratedNothing) && !mentionedEntities.isEmpty
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

    /// Coverages that can be pointed at, in the order they were spoken.
    var located: [BeatCoverage] {
        covered.filter(\.isLocated).sorted { ($0.at ?? 0) < ($1.at ?? 0) }
    }

    var climaxCoverage: BeatCoverage? {
        covered.first { $0.beat.isClimax }
    }

    /// The turning point, only when the moment it was told is known — the pace and
    /// expression rules need a time, not just the knowledge that it was covered.
    var locatedClimax: BeatCoverage? {
        located.first { $0.beat.isClimax }
    }

    /// When a covered beat was told, from the moment it was mentioned to the moment the
    /// next one was. Used to check pace and expression at the point that mattered.
    func span(of coverage: BeatCoverage, endingBy end: TimeInterval) -> Range<TimeInterval> {
        guard let start = coverage.at else { return 0..<end }
        let next = located.first { ($0.at ?? 0) > start }?.at ?? end
        return start..<max(start + 0.5, next)
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
