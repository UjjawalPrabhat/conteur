import Foundation
import Testing

@testable import Conteur

/// The annotation is ground truth, so an error in it is worse than a bug in the analysis —
/// it would make the app confidently wrong. These tests check the authoring, not the code.
struct StoryLibraryTests {
    @Test(arguments: StoryLibrary.all)
    func lengthSitsInTheResearchEnvelope(story: GuidedStory) {
        // Story-grammar and adult recall research used passages of roughly this size, and
        // a single reading has to stay under a couple of minutes.
        #expect(story.wordCount >= 250)
        #expect(story.wordCount <= 550)
        #expect(story.readingTime <= 130)
    }

    @Test(arguments: StoryLibrary.all)
    func retellingIsExpectedToRunUnderTwoMinutes(story: GuidedStory) {
        // At around 150 words a minute of narrative speech.
        let longest = Double(story.expectedRetellingWords.upperBound) / 150 * 60
        #expect(longest <= 120)
    }

    @Test(arguments: StoryLibrary.all)
    func beatsAreNumberedFromOneWithoutGaps(story: GuidedStory) {
        #expect(story.beats.map(\.id) == Array(1...story.beats.count))
    }

    /// Recall degrades sharply past this, and more beats would confound structure with
    /// memory load.
    @Test(arguments: StoryLibrary.all)
    func thereAreFiveToSevenBeats(story: GuidedStory) {
        #expect(story.beats.count >= 5)
        #expect(story.beats.count <= 7)
    }

    @Test(arguments: StoryLibrary.all)
    func causalLinksPointAtEarlierBeats(story: GuidedStory) {
        for beat in story.beats {
            guard let cause = beat.causedBy else { continue }
            #expect(cause < beat.id, "beat \(beat.id) of \(story.id) is caused by a later beat")
            #expect(story.beat(cause) != nil)
        }
    }

    @Test(arguments: StoryLibrary.all)
    func onlyTheOpeningBeatHasNoCause(story: GuidedStory) {
        let uncaused = story.beats.filter { $0.causedBy == nil }
        #expect(uncaused.map(\.id) == [1])
    }

    @Test(arguments: StoryLibrary.all)
    func everyEntityNamedInABeatIsInTheCast(story: GuidedStory) {
        let cast = Set(story.cast.map(\.name))
        for beat in story.beats {
            for entity in beat.entities {
                #expect(cast.contains(entity), "\(story.id) beat \(beat.id) names unknown \(entity)")
            }
        }
    }

    @Test(arguments: StoryLibrary.all)
    func everyCentralCharacterAppearsInABeat(story: GuidedStory) {
        let named = Set(story.beats.flatMap(\.entities))
        for entity in story.centralCast {
            #expect(named.contains(entity.name), "\(story.id) never uses central \(entity.name)")
        }
    }

    /// Genre sets what a listener expects. A story that does not contain what its own genre
    /// promises would be marked down for the author's choice rather than the reteller's.
    @Test(arguments: StoryLibrary.all)
    func theStoryContainsWhatItsGenreExpects(story: GuidedStory) {
        let missing = story.genre.expectedComponents.subtracting(story.presentComponents)
        #expect(missing.isEmpty, "\(story.id) is a \(story.genre.rawValue) missing \(missing)")
    }

    @Test(arguments: StoryLibrary.all)
    func theStakesAreStated(story: GuidedStory) {
        #expect(story.stakes.split(separator: " ").count >= 6)
    }

    @Test func identifiersAreUnique() {
        #expect(Set(StoryLibrary.all.map(\.id)).count == StoryLibrary.all.count)
    }
}
