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

    private let matcher = SourceMatcher()

    func compare(_ transcript: Transcript, with story: GuidedStory) async throws -> SourceComparison {
        guard !transcript.words.isEmpty else { return .nothing(for: story) }

        let entities = matcher.entities(in: transcript, from: story)
        let draft = try? await coverage(of: transcript, against: story)

        // A quote the model produced that is not actually in the retelling is a
        // fabrication, and dropping it here is what keeps one out of the feedback.
        let covered = (draft?.mentions ?? [])
            .filter(\.covered)
            .compactMap { mention -> BeatCoverage? in
                guard
                    let beat = story.beat(mention.beat),
                    let at = transcript.locate(mention.quote)
                else { return nil }
                return BeatCoverage(beat: beat, quote: mention.quote, at: at)
            }
            .sorted { $0.at < $1.at }

        let coveredIDs = Set(covered.map(\.beat.id))

        return SourceComparison(
            story: story,
            covered: covered,
            omitted: story.beats.filter { !coveredIDs.contains($0.id) },
            mentionedEntities: entities.mentioned,
            omittedEntities: entities.omitted,
            inventedNames: matcher.inventedNames(in: transcript, from: story),
            orderAccuracy: matcher.orderAccuracy(of: covered),
            compression: Double(transcript.words.count) / Double(max(story.wordCount, 1)),
            conveyedStakes: draft?.conveyedStakes ?? false
        )
    }

    private func coverage(
        of transcript: Transcript,
        against story: GuidedStory
    ) async throws -> CoverageDraft {
        let session = LanguageModelSession(instructions: Self.instructions)
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

        Covered means they conveyed that event in their own words. It does not have to
        match the wording. It does have to be there — if they did not tell it, say so.

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
