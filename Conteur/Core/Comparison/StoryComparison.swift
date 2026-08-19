import Foundation
import FoundationModels

protocol SourceComparing: Sendable {
    func compare(_ transcript: Transcript, with story: GuidedStory) async throws -> SourceComparison
}

/// Measures a retelling against the story it came from.
///
/// The whole comparison fits one model session — a 350-word story's beat sheet plus a
/// 180-word retelling plus instructions runs about a thousand tokens against a budget of
/// 4,096. So there is no chunking and no map-reduce here: that machinery existed only
/// because structure had to be inferred with nothing to compare against.
///
/// The model is asked one narrow question — which of these numbered events does the
/// retelling cover, and quote the words — where "none of them" is a legal answer.
/// Everything else is computed by `SourceMatcher`.
struct StoryComparison: SourceComparing {
    private static let options = GenerationOptions(sampling: .greedy)

    /// The default guardrails refused six of fifteen scripted retellings, every faithful one
    /// among them — a story where a mother dies reads as unsafe to a classifier that cannot
    /// see it is fiction the app itself wrote. This is a transformation of supplied content,
    /// not open generation, so the permissive setting is the accurate one.
    private static let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)

    /// A retelling cannot cover more events than it has words for. Measured against the
    /// faithful samples, which run 25 to 35 words per event told.
    private static let wordsPerClaimedEvent = 20

    private let matcher = SourceMatcher()

    func compare(_ transcript: Transcript, with story: GuidedStory) async throws -> SourceComparison {
        guard !transcript.words.isEmpty else { return .nothing(for: story) }

        let entities = matcher.entities(in: transcript, from: story)
        let draft = try await coverage(of: transcript, against: story)

        // A quote that is not actually in the retelling is a fabrication and must never be
        // shown — but the beat is still covered. So the quote is dropped, not the coverage.
        let claimed = draft.mentions
            .filter(\.covered)
            .compactMap { mention -> BeatCoverage? in
                guard let beat = story.beat(mention.beat) else { return nil }
                guard let at = transcript.locate(mention.quote) else {
                    return BeatCoverage(beat: beat, quote: nil, at: nil)
                }
                return BeatCoverage(beat: beat, quote: mention.quote, at: at)
            }
            .sorted { ($0.at ?? .greatestFiniteMagnitude) < ($1.at ?? .greatestFiniteMagnitude) }

        let plausible = Self.plausible(claimed, in: transcript)
        let coveredIDs = Set(plausible.map(\.beat.id))

        return SourceComparison(
            story: story,
            covered: plausible,
            omitted: story.beats.filter { !coveredIDs.contains($0.id) },
            mentionedEntities: entities.mentioned,
            omittedEntities: entities.omitted,
            inventedNames: matcher.inventedNames(in: transcript, from: story),
            orderAccuracy: matcher.orderAccuracy(of: plausible),
            compression: Double(transcript.words.count) / Double(max(story.wordCount, 1)),
            conveyedStakes: draft.conveyedStakes
        )
    }

    /// When a retelling stops early the model finishes the story from what it knows: one
    /// sample told two events and was credited with all five. Claims it could not quote are
    /// kept only up to what the retelling's length supports, since a located claim carries
    /// its own evidence and an unlocated one carries none.
    private static func plausible(_ covered: [BeatCoverage], in transcript: Transcript) -> [BeatCoverage] {
        let located = covered.filter(\.isLocated)
        let unlocated = covered.filter { !$0.isLocated }
        let budget = transcript.words.count / wordsPerClaimedEvent - located.count
        guard budget < unlocated.count else { return covered }
        return located + unlocated.prefix(max(0, budget))
    }

    private func coverage(
        of transcript: Transcript,
        against story: GuidedStory
    ) async throws -> CoverageDraft {
        let session = LanguageModelSession(model: Self.model, instructions: Self.instructions)
        return try await session.respond(
            to: Self.brief(transcript, story),
            generating: CoverageDraft.self,
            options: Self.options
        ).content
    }

    private static func brief(_ transcript: Transcript, _ story: GuidedStory) -> String {
        """
        THE STORY'S EVENTS
        \(story.beats.map { "\($0.id). \($0.summary)" }.joined(separator: "\n"))

        WHY IT MATTERED
        \(story.stakes)

        WHAT THEY SAID
        \(transcript.text)
        """
    }

    private static let instructions = """
        Somebody read a short story and then retold it from memory. You are given the
        story's events as a numbered list, and what they actually said.

        For every numbered event, say whether their retelling covers it.

        Answer for every event on the list, including the last one. Do not stop early.

        Covered means they conveyed that event in their own words. It does not have to
        match the wording. It does have to be there — if they did not tell it, say so.

        Do not fill in the rest of the story from what you can guess. A retelling that stops
        halfway covers only what it reached.

        When an event is covered, quote the words from their retelling that cover it.
        Copy the words exactly as they said them. Never write a quote they did not say.

        Then say whether they got across why the story mattered, as described above.
        Recounting the events is not enough on its own.
        """
}

@Generable
private struct CoverageDraft {
    @Guide(description: "One entry for every numbered event in the story, in order.")
    var mentions: [BeatMention]

    @Guide(description: "True only if they conveyed why the story mattered, not just what happened.")
    var conveyedStakes: Bool
}

@Generable
private struct BeatMention {
    @Guide(description: "The number of the event.")
    var beat: Int

    @Guide(description: "True only if the retelling actually covers this event.")
    var covered: Bool

    @Guide(description: "The exact words they said that cover it. Empty if not covered.")
    var quote: String
}
