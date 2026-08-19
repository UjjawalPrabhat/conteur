import Foundation
import FoundationModels

/// Runs the map-reduce over the on-device model.
///
/// Each call opens its own session: sessions accumulate context, and the model's
/// budget covers instructions plus prompts plus responses together, so a shared
/// session would exhaust it partway through a long retelling.
struct OnDeviceNarrativeAnalyzer: NarrativeAnalyzing {
    enum Failure: Error, LocalizedError {
        case deviceNotEligible
        case appleIntelligenceDisabled
        case modelNotReady

        var errorDescription: String? {
            switch self {
            case .deviceNotEligible:
                "This iPhone can't run on-device analysis."
            case .appleIntelligenceDisabled:
                "Turn on Apple Intelligence in Settings so Conteur can analyse your retelling."
            case .modelNotReady:
                "The on-device model is still preparing. Try again in a moment."
            }
        }
    }

    /// Greedy sampling keeps labels reproducible: the same recording must always
    /// produce the same findings, or attempt-to-attempt comparison is meaningless.
    private static let options = GenerationOptions(sampling: .greedy)

    func label(_ chunk: TranscriptChunk) async throws -> Beat {
        try Self.checkAvailability()

        let session = LanguageModelSession(instructions: Self.labellingInstructions)
        let draft = try await session.respond(
            to: chunk.text,
            generating: BeatDraft.self,
            options: Self.options
        ).content

        return Beat(
            start: chunk.start,
            end: chunk.end,
            summary: draft.summary,
            kind: SpanKind(draft.kind),
            entitiesIntroduced: draft.entitiesIntroduced.normalizedEntities,
            entitiesReferenced: draft.entitiesReferenced.normalizedEntities,
            statesStakes: draft.statesStakes,
            connectsCausally: draft.connectsCausally
        )
    }

    func arc(from beats: [Beat]) async throws -> NarrativeArc {
        guard !beats.isEmpty else { return NarrativeReading.empty.arc }
        try Self.checkAvailability()

        let session = LanguageModelSession(instructions: Self.arcInstructions)
        let draft = try await session.respond(
            to: Self.beatSheet(from: beats),
            generating: ArcDraft.self,
            options: Self.options
        ).content

        return NarrativeArc(
            shape: StoryShape(draft.shape),
            present: Set(draft.componentsPresent.map(StoryComponent.init)),
            climaxBeat: beats.indices.contains(draft.climaxBeatNumber - 1)
                ? draft.climaxBeatNumber - 1
                : nil,
            sequencingIsFollowable: draft.sequencingIsFollowable
        )
    }

    private static func checkAvailability() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            return
        case .unavailable(.deviceNotEligible):
            throw Failure.deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            throw Failure.appleIntelligenceDisabled
        case .unavailable(.modelNotReady):
            throw Failure.modelNotReady
        case .unavailable:
            throw Failure.modelNotReady
        }
    }

    /// A compact rendering: the reduce step reasons over summaries, never raw speech,
    /// which is what keeps a ten-minute retelling inside one session.
    private static func beatSheet(from beats: [Beat]) -> String {
        beats.enumerated()
            .map { index, beat in
                "\(index + 1). [\(beat.kind.rawValue)] \(beat.summary)"
            }
            .joined(separator: "\n")
    }

    private static let labellingInstructions = """
        You label one stretch of somebody retelling a story they just read.

        Judge only the stretch you are given. Do not invent detail that is not there.

        For the kind, pick what the stretch mostly does:
        corePlot — events the story turns on
        context — background needed to follow those events
        character — who somebody is, what they want
        emotional — what an event meant or how it felt
        lowValue — accurate but inconsequential detail
        offTopic — not about the story

        Entities are named people, places and objects. When uncertain, prefer
        referenced over introduced. A pronoun like "he", "she", "they", "him", "her",
        "them", or a definite phrase like "the brother", "the house", "the city"
        counts as referenced, not introduced, unless this stretch actually defines
        or describes the entity for the first time. Only mark something as introduced
        when this stretch clearly presents it as new information.

        Stakes means the stretch says what is at risk or why an event matters.
        Causal means events are joined by cause rather than just sequence: "because",
        "which meant", "so" — not "and then".
        """

    private static let arcInstructions = """
        You read a numbered list of beats from somebody retelling a story, and
        describe the shape of the retelling as a whole.

        Shape: plotDriven if events drive it, characterDriven if a person's change
        does, thematic if it is about meaning more than events, episodic if it is a
        series of happenings with no single arc.

        List only the components the beats actually contain.

        The climax is the beat carrying the most tension or consequence.

        Sequencing is followable when a listener could reconstruct the order of
        events without rereading.
        """
}

@Generable
private struct BeatDraft {
    @Guide(description: "One sentence: what happens in this stretch.")
    var summary: String

    @Guide(description: "What this stretch mostly does.")
    var kind: SpanKindDraft

    @Guide(description: "Named people, places or objects appearing here for the first time.")
    var entitiesIntroduced: [String]

    @Guide(description: "Named people, places or objects already established earlier.")
    var entitiesReferenced: [String]

    @Guide(description: "True if this stretch says what is at risk or why it matters.")
    var statesStakes: Bool

    @Guide(description: "True if events here are joined by cause rather than just sequence.")
    var connectsCausally: Bool
}

@Generable
private struct ArcDraft {
    @Guide(description: "The shape of the retelling as a whole.")
    var shape: StoryShapeDraft

    @Guide(description: "Only the components the beats actually contain.")
    var componentsPresent: [StoryComponentDraft]

    @Guide(description: "The number of the beat carrying the most tension or consequence.")
    var climaxBeatNumber: Int

    @Guide(description: "True if a listener could follow the order of events.")
    var sequencingIsFollowable: Bool
}

// The model-facing enums are declared separately so the shared domain types stay
// free of any dependency on FoundationModels.

@Generable
private enum SpanKindDraft {
    case corePlot
    case context
    case character
    case emotional
    case lowValue
    case offTopic
}

@Generable
private enum StoryShapeDraft {
    case plotDriven
    case characterDriven
    case thematic
    case episodic
}

@Generable
private enum StoryComponentDraft {
    case setting
    case initiatingEvent
    case goal
    case conflict
    case attempts
    case consequences
    case resolution
}

private extension SpanKind {
    init(_ draft: SpanKindDraft) {
        switch draft {
        case .corePlot: self = .corePlot
        case .context: self = .context
        case .character: self = .character
        case .emotional: self = .emotional
        case .lowValue: self = .lowValue
        case .offTopic: self = .offTopic
        }
    }
}

private extension StoryShape {
    init(_ draft: StoryShapeDraft) {
        switch draft {
        case .plotDriven: self = .plotDriven
        case .characterDriven: self = .characterDriven
        case .thematic: self = .thematic
        case .episodic: self = .episodic
        }
    }
}

private extension StoryComponent {
    init(_ draft: StoryComponentDraft) {
        switch draft {
        case .setting: self = .setting
        case .initiatingEvent: self = .initiatingEvent
        case .goal: self = .goal
        case .conflict: self = .conflict
        case .attempts: self = .attempts
        case .consequences: self = .consequences
        case .resolution: self = .resolution
        }
    }
}

private extension [String] {
    /// Entity tracking is a set comparison across beats, so casing and stray
    /// articles would otherwise hide a thread that was in fact picked up again.
    var normalizedEntities: [String] {
        compactMap { entity in
            let trimmed = entity
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let stripped = ["the ", "a ", "an ", "his ", "her ", "their "]
                .first { trimmed.hasPrefix($0) }
                .map { String(trimmed.dropFirst($0.count)) } ?? trimmed
            return stripped.isEmpty ? nil : stripped
        }
    }
}
