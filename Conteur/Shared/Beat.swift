import Foundation

/// What a stretch of the retelling is doing. Time spent per kind is what makes
/// "you spent 42 seconds on the drive" computable.
enum SpanKind: String, Sendable, Hashable, CaseIterable {
    case corePlot
    case context
    case character
    case emotional
    case lowValue
    case offTopic
}

/// One labelled stretch of the retelling, anchored to the audio.
struct Beat: Sendable, Hashable {
    let start: TimeInterval
    let end: TimeInterval
    let summary: String
    let kind: SpanKind
    let entitiesIntroduced: [String]
    let entitiesReferenced: [String]
    let statesStakes: Bool
    let connectsCausally: Bool

    var duration: TimeInterval { end - start }
}

// MARK: - Entity resolution

private let pronouns: Set<String> = [
    "he", "she", "they", "him", "her", "them",
    "his", "hers", "theirs"
]

extension [Beat] {
    /// The model labels each chunk in isolation, so it has no memory of what it
    /// labelled in earlier chunks. A chunk that starts with "So he..." or "Then
    /// the brother..." may be mislabelled as introducing an entity that was in fact
    /// established earlier in the same retelling. This pass reclassifies those
    /// false introductions as references, using only the session's own output as
    /// context — no extra model calls.
    ///
    /// The rule is simple: once an entity has appeared anywhere in the session
    /// (in either introduced or referenced), it cannot be introduced again.
    /// Pronouns are always references.
    func resolveEntities() -> [Beat] {
        var seen: Set<String> = []
        return map { beat in
            let alreadySeen = seen

            let reclassified = beat.entitiesIntroduced.filter { entity in
                pronouns.contains(entity) || alreadySeen.contains(entity)
            }

            let corrected = Beat(
                start: beat.start,
                end: beat.end,
                summary: beat.summary,
                kind: beat.kind,
                entitiesIntroduced: beat.entitiesIntroduced.filter { entity in
                    !pronouns.contains(entity) && !alreadySeen.contains(entity)
                },
                entitiesReferenced: beat.entitiesReferenced + reclassified,
                statesStakes: beat.statesStakes,
                connectsCausally: beat.connectsCausally
            )

            seen.formUnion(beat.entitiesIntroduced)
            seen.formUnion(beat.entitiesReferenced)
            return corrected
        }
    }
}

/// Applying one structural template to every retelling penalizes stories that
/// legitimately lack a tidy resolution, so expectations are conditioned on shape.
enum StoryShape: String, Sendable, Hashable, CaseIterable {
    case plotDriven
    case characterDriven
    case thematic
    case episodic
}

enum StoryComponent: String, Sendable, Hashable, CaseIterable {
    case setting
    case initiatingEvent
    case goal
    case conflict
    case attempts
    case consequences
    case resolution

    /// Which components a listener would expect to hear for a given shape.
    static func expected(for shape: StoryShape) -> Set<StoryComponent> {
        switch shape {
        case .plotDriven:
            [.setting, .initiatingEvent, .conflict, .attempts, .consequences, .resolution]
        case .characterDriven:
            [.setting, .initiatingEvent, .goal, .conflict, .consequences]
        case .thematic:
            [.setting, .conflict, .consequences]
        case .episodic:
            [.setting, .initiatingEvent, .attempts]
        }
    }
}

struct NarrativeArc: Sendable, Hashable {
    let shape: StoryShape
    let present: Set<StoryComponent>
    /// Index into the beat list, so the climax can be cross-referenced against pace
    /// and expressivity at the same moment.
    let climaxBeat: Int?
    let sequencingIsFollowable: Bool

    var missing: Set<StoryComponent> {
        StoryComponent.expected(for: shape).subtracting(present)
    }
}

struct NarrativeReading: Sendable {
    let beats: [Beat]
    let arc: NarrativeArc

    static let empty = NarrativeReading(
        beats: [],
        arc: NarrativeArc(shape: .episodic, present: [], climaxBeat: nil, sequencingIsFollowable: true)
    )
}
