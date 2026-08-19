import Foundation
import Testing

@testable import Conteur

struct SourceMatcherTests {
    private let matcher = SourceMatcher()
    private let story = StoryLibrary.thirdCast

    // MARK: - Entities

    @Test func aCharacterNamedDirectlyCountsAsMentioned() {
        let mentioned = matcher.entities(in: retelling("Aren went out fishing"), from: story).mentioned

        #expect(mentioned.contains { $0.name == "Aren" })
    }

    /// Retellings almost never reuse the story's exact nouns, so matching on the name alone
    /// would badly under-count what was actually covered.
    @Test func anAliasCountsJustAsMuchAsTheName() {
        let mentioned = matcher.entities(
            in: retelling("the fisherman met a talking fish"),
            from: story
        ).mentioned

        #expect(mentioned.contains { $0.name == "Aren" })
        #expect(mentioned.contains { $0.name == "the silver fish" })
    }

    @Test func aCharacterLeftOutIsReportedOmitted() {
        let omitted = matcher.entities(in: retelling("Aren caught a fish"), from: story).omitted

        #expect(omitted.contains { $0.name == "Mira" })
    }

    @Test func caseAndPunctuationDoNotHideAMention() {
        let mentioned = matcher.entities(in: retelling("MIRA, quietly, said nothing"), from: story).mentioned

        #expect(mentioned.contains { $0.name == "Mira" })
    }

    /// Substring matching counted "she" inside "shes"; entity matching is on whole words.
    @Test func aWordInsideAnotherWordIsNotAMention() {
        let mentioned = matcher.entities(in: retelling("the ashes were cold"), from: story).mentioned

        #expect(mentioned.isEmpty)
    }

    // MARK: - Invented names

    /// The failure this exists for: a retelling — or an analysis of one — populated with
    /// people the story never had.
    @Test func aNameTheStoryNeverHadIsFlagged() {
        let invented = matcher.inventedNames(
            in: retelling("so Alex spoke to Jordan about the decision"),
            from: story
        )

        #expect(invented.map(\.name) == ["Alex", "Jordan"])
        // Located, so the feedback can point at the moment rather than at 0:00.
        #expect(invented.allSatisfy { $0.at > 0 })
    }

    @Test func theStoryOwnCharactersAreNeverFlagged() {
        let invented = matcher.inventedNames(
            in: retelling("so Aren asked Mira about Coldhaven"),
            from: story
        )

        #expect(invented.isEmpty)
    }

    /// A capitalised word opening a sentence is just a sentence opening.
    @Test func aSentenceInitialWordIsNotAnInvention() {
        let invented = matcher.inventedNames(
            in: retelling("He fished for years. Then everything changed."),
            from: story
        )

        #expect(invented.isEmpty)
    }

    /// "Elspeth's" was being reported as a character the story never had.
    @Test func aPossessiveIsTheSameName() {
        let invented = matcher.inventedNames(in: retelling("she read Mira's letters"), from: story)

        #expect(invented.isEmpty)
    }

    // MARK: - Order

    @Test func tellingEventsInOrderScoresPerfectly() {
        #expect(matcher.orderAccuracy(of: coverage([1, 2, 3, 4])) == 1)
    }

    @Test func tellingEventsBackwardsScoresZero() {
        #expect(matcher.orderAccuracy(of: coverage([4, 3, 2, 1])) == 0)
    }

    /// One displaced event should cost a little, not everything — which is why this is a
    /// concordant-pair measure rather than a strict-sequence check.
    @Test func oneDisplacedEventCostsOnlyALittle() {
        let accuracy = matcher.orderAccuracy(of: coverage([1, 2, 4, 3, 5]))

        #expect(accuracy > 0.85)
        #expect(accuracy < 1)
    }

    @Test func asingleEventHasNoOrderToGetWrong() {
        #expect(matcher.orderAccuracy(of: coverage([3])) == 1)
    }

    // MARK: - Locating quotes

    @Test func aQuoteFromTheRetellingIsLocated() {
        let transcript = retelling("he asked the fish for the whole sea")

        #expect(transcript.locate("asked the fish") != nil)
    }

    /// The guard against a fabricated quote: the model is told to copy words from the
    /// retelling, and anything it did not copy cannot be found here and is discarded.
    @Test func aQuoteThatWasNeverSaidIsNotLocated() {
        let transcript = retelling("he asked the fish for the whole sea")

        #expect(transcript.locate("Alex spoke to Jordan") == nil)
    }

    @Test func punctuationInTheTranscriptDoesNotBlockAMatch() {
        let transcript = retelling("the sea went still, and everything was gone")

        #expect(transcript.locate("still and everything") != nil)
    }

    @Test func aLocatedQuoteReportsWhenItWasSaid() {
        let transcript = retelling("one two three four five")

        #expect(transcript.locate("three four") == 2 * 0.4)
    }

    // MARK: - Fixtures

    private func retelling(_ text: String) -> Transcript {
        let words = text.split(separator: " ").enumerated().map { index, word in
            SpokenWord(text: String(word), start: Double(index) * 0.4, end: Double(index) * 0.4 + 0.2)
        }
        return Transcript(words: words)
    }

    private func coverage(_ beatIDs: [Int]) -> [BeatCoverage] {
        beatIDs.enumerated().map { index, id in
            BeatCoverage(
                beat: story.beat(id) ?? story.beats[0],
                quote: "word",
                at: Double(index)
            )
        }
    }
}
