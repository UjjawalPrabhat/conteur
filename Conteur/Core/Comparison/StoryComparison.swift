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
    /// Capped output, but not tightly. Unbounded, the model rambles when there is nothing to
    /// quote and fills the 4,096-token window. Capped at 100 it was cut off mid-structure and
    /// three samples failed to deserialize instead — retrying cannot help, since greedy
    /// sampling truncates in exactly the same place. This leaves room for the schema and a
    /// sentence of quote while still bounding a ramble.
    private static let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 300)

    /// Concurrent calls, but not one per event unbounded. Seven at once brought back refusals
    /// and deserialization failures that were absent in series, which points at contention.
    private static let concurrentJudgements = 3

    /// The default guardrails refused six of fifteen scripted retellings, every faithful one
    /// among them — a story where a mother dies reads as unsafe to a classifier that cannot
    /// see it is fiction the app itself wrote. This is a transformation of supplied content,
    /// not open generation, so the permissive setting is the accurate one.
    private static let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)

    /// How much of an event's own vocabulary has to be present to overrule a denial.
    ///
    /// Measured against the corpus: three recovers three real coverages and wrongly credits
    /// nothing, where two recovers a fourth and puts back a commentary sample that eight runs
    /// went into clearing. The margin either side is a single sample, so this is the least
    /// trustworthy number here.
    private static let strongOverlap = 3

    /// Refusals are not reproducible: the same sample was answered on one run and refused on
    /// the next. One retry is worth more than it costs.
    private static let attempts = 2

    private let matcher = SourceMatcher()

    func compare(_ transcript: Transcript, with story: GuidedStory) async throws -> SourceComparison {
        guard !transcript.words.isEmpty else { return .nothing(for: story) }
        // Asked before anything else, because every path below needs the model and the
        // framework's own error for a missing one is not something to show a person.
        guard case .available = Self.model.availability else { throw ModelFailure.unavailable }

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

        // Commentary was over-credited in every run. The check is on the story's side: an
        // event that brings its own names with it did not happen in a retelling that never
        // says any of them.
        let corroborated = claimed.filter {
            matcher.corroborates(transcript, $0.beat, in: story)
        }
        let rejected = claimed.filter {
            !matcher.corroborates(transcript, $0.beat, in: story)
        }

        // The same evidence read the other way. The model denied events whose own vocabulary
        // was plainly present — five of the eight words belonging to one of them, in a
        // retelling it said had not covered it. Where the evidence is that strong it outweighs
        // the judgement. Unlocated on purpose: the words are scattered, and a one-word quote
        // is not something to show anybody.
        let denied = draft.mentions.filter { !$0.covered }.compactMap { story.beat($0.beat) }
        let recovered = denied
            .filter { matcher.vocabularyOverlap(transcript, $0, in: story) >= Self.strongOverlap }
            .map { BeatCoverage(beat: $0, quote: nil, at: nil) }

        let covered = corroborated + recovered
        let coveredIDs = Set(covered.map(\.beat.id))
        let judged = story.beats.filter { !draft.unresolved.contains($0.id) }

        return SourceComparison(
            story: story,
            covered: covered,
            omitted: judged.filter { !coveredIDs.contains($0.id) },
            rejected: rejected.map(\.beat),
            unresolved: story.beats.filter { draft.unresolved.contains($0.id) },
            mentionedEntities: entities.mentioned,
            omittedEntities: entities.omitted,
            inventedNames: matcher.inventedNames(in: transcript, from: story),
            orderAccuracy: matcher.orderAccuracy(of: covered),
            compression: Double(transcript.words.count) / Double(max(story.wordCount, 1)),
            conveyedStakes: draft.conveyedStakes
        )
    }

    private func coverage(
        of transcript: Transcript,
        against story: GuidedStory
    ) async throws -> (mentions: [BeatMention], unresolved: Set<Int>, conveyedStakes: Bool) {
        // Each event is judged on its own against the same retelling, so they are
        // independent and there is no reason to wait for one before asking the next. In
        // series the corpus took nearly seven minutes.
        var judgements: [(id: Int, draft: CoverageDraft?)] = []
        var refusal: ModelFailure?
        await withTaskGroup(of: (id: Int, draft: CoverageDraft?, failure: ModelFailure?).self) { group in
            var pending = story.beats.makeIterator()

            func addNext() {
                guard let event = pending.next() else { return }
                group.addTask {
                    do {
                        let draft = try await Self.attempting {
                            let session = LanguageModelSession(
                                model: Self.model,
                                instructions: Self.coverageInstructions
                            )
                            return try await session.respond(
                                to: Self.brief(transcript, event),
                                generating: CoverageDraft.self,
                                options: Self.options
                            ).content
                        }
                        return (event.id, draft, nil)
                    } catch {
                        return (event.id, nil, ModelFailure(error))
                    }
                }
            }

            for _ in 0..<Self.concurrentJudgements { addNext() }
            while let judgement = await group.next() {
                // One refused event used to fail the whole comparison, so a retelling of six
                // events got no feedback at all because of the seventh. The guardrail refuses
                // individual events unpredictably; the rest of the judgements are still good.
                refusal = judgement.failure ?? refusal
                judgements.append((judgement.id, judgement.draft))
                addNext()
            }
        }

        // Nothing was judged, so there is nothing to report. Only here is a refusal fatal.
        if judgements.allSatisfy({ $0.draft == nil }), let refusal { throw refusal }

        let answered = judgements.sorted { $0.id < $1.id }
        let mentions = answered.compactMap { judgement -> BeatMention? in
            guard let draft = judgement.draft else { return nil }
            return BeatMention(beat: judgement.id, covered: draft.covered, quote: draft.quote)
        }
        let unresolved = Set(answered.filter { $0.draft == nil }.map(\.id))

        // A refusal here is not fatal either: the point of the story is one finding among
        // many, and losing it is no reason to lose the coverage as well.
        let stakes = try? await Self.attempting {
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
        let conveyed = stakes.flatMap { transcript.locate($0.quote) } != nil

        return (mentions, unresolved, conveyed)
    }

    private static func attempting<T>(_ work: () async throws -> T) async throws -> T {
        var lastError: any Error = CancellationError()
        for _ in 0..<Self.attempts {
            do { return try await work() } catch { lastError = error }
        }
        throw lastError
    }

    private static func brief(_ transcript: Transcript, _ event: CanonicalBeat) -> String {
        """
        AN EVENT FROM THE STORY
        \(event.summary)

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
        Somebody read a short story and then retold it from memory. You are given one event
        from the story and what they said.

        Say whether their retelling covers that event. It does not have to match the wording.
        It does have to be there — if they did not tell it, say no.

        Naming a character or a place is not telling an event. Talking about the story, or
        guessing at it, is not telling an event either.

        If they covered it, quote the words that cover it, exactly as they said them, and keep
        the quote short. If they did not, answer no and leave the quote empty. Never write a
        quote they did not say.
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
    @Guide(description: "True only if the retelling actually covers this event.")
    var covered: Bool

    @Guide(description: "The words they said that cover it, kept short. Empty if not covered.")
    var quote: String
}

@Generable
private struct StakesDraft {
    @Guide(description: "The words they said that get the point across. Empty if they never did.")
    var quote: String
}

/// Which event, and what the model said about it. The number comes from the request rather
/// than the answer, so the model cannot misattribute a judgement.
private struct BeatMention {
    let beat: Int
    let covered: Bool
    let quote: String
}
