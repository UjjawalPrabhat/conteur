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
