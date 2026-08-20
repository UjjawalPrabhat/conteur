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

    // MARK: - Corroboration

    /// Commentary was over-credited in every evaluation run. An event that brings its own words
    /// with it did not happen in a retelling that says none of them.
    @Test func anEventIsNotCorroboratedWhenNothingOfItIsThere() {
        let bargain = story.beat(3)!
        let commentary = retelling("I thought it was quite bleak. Aren deserved better.")

        #expect(matcher.corroborates(commentary, bargain, in: story) == false)
    }

    @Test func anEventIsCorroboratedWhenItsOwnWordsAreThere() {
        let bargain = story.beat(3)!
        let told = retelling("he pulled up a silver fish and it spoke to him")

        #expect(matcher.corroborates(told, bargain, in: story))
    }

    /// Naming the cast is how a cast is tracked, not how an event is recognised. Requiring a
    /// name threw out eight real coverages: a paraphrase told these events without saying Mira.
    @Test func anEventIsCorroboratedWithoutItsCastBeingNamed() throws {
        let paraphrased = try #require(
            RetellingCorpus.all.first { $0.storyID == story.id && $0.shape == .paraphrased }
        )

        let ending = try #require(story.beat(7))
        #expect(ending.entities.contains("Mira"))
        #expect(paraphrased.transcript.contains(phrase: "Mira") == false)
        #expect(matcher.corroborates(paraphrased.transcript, ending, in: story))
    }

    /// The limit of the same check, stated so it is not mistaken for a bug later: an event a
    /// paraphrase tells in none of its own words cannot be corroborated, and is missed.
    @Test func anEventToldEntirelyInOtherWordsIsStillMissed() throws {
        let paraphrased = try #require(
            RetellingCorpus.all.first { $0.storyID == story.id && $0.shape == .paraphrased }
        )
        let opening = try #require(story.beat(1))

        #expect(matcher.vocabularyOverlap(paraphrased.transcript, opening, in: story) == 0)
    }

    /// An event carrying no distinctive name used to be waved through, which is how commentary
    /// kept being credited with the opening. It is checked against its own vocabulary instead.
    @Test func anEventWithNoDistinctiveNameIsCheckedAgainstItsOwnWords() {
        let story = StoryLibrary.theNineFifteen
        let waiting = story.beat(4)!

        #expect(matcher.corroborates(retelling("she waited there"), waiting, in: story) == false)
        #expect(
            matcher.corroborates(
                retelling("she waited in a service lane with her phone out"),
                waiting,
                in: story
            )
        )
    }

    /// The model credited events on the strength of a character being mentioned. Naming the
    /// cast is not telling an event, so the cast alone cannot corroborate one.
    @Test func namingTheCastIsNotTellingTheEvent() {
        let asking = story.beat(5)!
        let named = retelling("Aren was in it, and Mira, and the silver fish as well")

        #expect(matcher.corroborates(named, asking, in: story) == false)
        #expect(matcher.corroborates(retelling("he asked for the entire sea"), asking, in: story))
    }

    /// The model denied events whose own vocabulary was plainly in the retelling. Counting the
    /// overlap is what lets strong evidence outweigh that judgement.
    @Test func vocabularyOverlapCountsHowMuchOfTheEventIsThere() {
        let story = StoryLibrary.whatTheHouseKept
        let letters = story.beat(2)!
        let told = retelling(
            "at the writing desk she found about sixty letters her mother wrote, all unopened"
        )

        #expect(matcher.vocabularyOverlap(told, letters, in: story) >= 3)
        #expect(matcher.vocabularyOverlap(retelling("it was quite sad"), letters, in: story) == 0)
    }

    /// The exact case from the evaluation runs: the model denied this event in three
    /// consecutive runs on a retelling that carries its vocabulary. Asserted against the corpus
    /// text rather than a hand-written line, so it pins what the device actually sees.
    @Test func theCorpusRetellingTheModelDeniedCarriesTheEventsVocabulary() throws {
        let story = StoryLibrary.whatTheHouseKept
        let letters = try #require(story.beat(2))
        let sample = try #require(
            RetellingCorpus.all.first { $0.storyID == story.id && $0.shape == .faithful }
        )

        #expect(matcher.vocabularyOverlap(sample.transcript, letters, in: story) >= 3)
    }

    @Test func aWordTwoEventsShareIsNotDistinctive() {
        let asking = story.beat(5)!

        let words = matcher.distinctiveWords(of: asking, in: story)

        #expect(words.contains("sea"))
        #expect(words.contains("asks") == false)
    }

    /// Without this, a summary that happens to be the only one saying "into" is corroborated by
    /// any retelling containing the word.
    @Test func aFunctionWordIsNeverDistinctive() {
        for beat in story.beats {
            let words = matcher.distinctiveWords(of: beat, in: story)
            #expect(words.contains("their") == false)
            #expect(words.contains("with") == false)
        }
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
