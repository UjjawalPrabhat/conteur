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

    /// One event per request.
    ///
    /// Asked about several at once the model answers per batch rather than per event: on every
    /// commentary sample it credited exactly the first batch of three and nothing after it,
    /// which is position rather than judgement. Batching three at a time had already cut
    /// refusals from nine samples to one; going to one removes the anchoring as well, at the
    /// cost of one small call per event.
    private static let eventsPerRequest = 1

    /// Refusals are not reproducible: the same sample was answered on one run and refused on
    /// the next. One retry is worth more than it costs.
    private static let attempts = 2

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
    ) async throws -> (mentions: [BeatMention], conveyedStakes: Bool) {
        var mentions: [BeatMention] = []

        for batch in story.beats.chunks(of: Self.eventsPerRequest) {
            // A batch that will not answer is thrown rather than treated as uncovered: an
            // unanswered event reported as an omission blames the speaker for a refusal.
            let draft = try await attempting {
                let session = LanguageModelSession(
                    model: Self.model,
                    instructions: Self.coverageInstructions
                )
                return try await session.respond(
                    to: Self.brief(transcript, batch),
                    generating: CoverageDraft.self,
                    options: Self.options
                ).content
            }
            mentions.append(contentsOf: draft.mentions)
        }

        let stakes = try await attempting {
            let session = LanguageModelSession(
                model: Self.model,
                instructions: Self.stakesInstructions
            )
            return try await session.respond(
                to: Self.stakesBrief(transcript, story),
                generating: StakesDraft.self,
                options: Self.options
            ).content
        }

        // Asked whether the point came through, it said yes for almost every sample including
        // the ones that narrated nothing. Made to quote the words that carry it, it has to
        // find them — and a quote that is not in the retelling is not evidence of anything.
        let conveyed = transcript.locate(stakes.quote) != nil

        return (mentions, conveyed)
    }

    private func attempting<T>(_ work: () async throws -> T) async throws -> T {
        var lastError: any Error = CancellationError()
        for _ in 0..<Self.attempts {
            do { return try await work() } catch { lastError = error }
        }
        throw lastError
    }

    private static func brief(_ transcript: Transcript, _ events: [CanonicalBeat]) -> String {
        """
        EVENTS FROM THE STORY
        \(events.map { "\($0.id). \($0.summary)" }.joined(separator: "\n"))

        WHAT THEY SAID
        \(transcript.text)
        """
    }

    private static func stakesBrief(_ transcript: Transcript, _ story: GuidedStory) -> String {
        """
        THE POINT OF THE STORY
        \(story.stakes)

        WHAT THEY SAID
        \(transcript.text)
        """
    }

    private static let coverageInstructions = """
        Somebody read a short story and then retold it from memory. You are given some of the
        story's events, numbered, and what they actually said.

        Answer for every event you are given, including the last one.

        Covered means they conveyed that event in their own words. It does not have to match
        the wording. It does have to be there — if they did not tell it, say so.

        Do not fill in the story from what you can guess. A retelling that stops early covers
        only what it reached, and somebody who merely names a character has not told an event.

        When an event is covered, quote the words from their retelling that cover it. Copy the
        words exactly as they said them. Never write a quote they did not say.
        """

    private static let stakesInstructions = """
        Somebody read a short story and then retold it from memory. You are given the point of
        the story and what they said.

        Quote the words they said that get that point across. Copy them exactly as they said
        them.

        If they only recounted what happened, or never reached the point at all, answer with
        nothing. Do not write a quote they did not say.
        """
}

@Generable
private struct CoverageDraft {
    @Guide(description: "One entry for every event you were given, in order.")
    var mentions: [BeatMention]
}

@Generable
private struct StakesDraft {
    @Guide(description: "The words they said that get the point across. Empty if they never did.")
    var quote: String
}

@Generable
fileprivate struct BeatMention {
    @Guide(description: "The number of the event.")
    var beat: Int

    @Guide(description: "True only if the retelling actually covers this event.")
    var covered: Bool

    @Guide(description: "The exact words they said that cover it. Empty if not covered.")
    var quote: String
}
