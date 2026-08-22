import Foundation

/// The stories the app gives you to read.
///
/// Written and annotated by hand rather than generated on the device. Two reasons: a 3B
/// model's prose is competent and forgettable, and nobody wants to retell a story that
/// bored them; and the annotation has to be *exact* to be worth having — an authored beat
/// sheet is ground truth, whereas one the model claims about its own output is another
/// inference.
///
/// Kept as Swift rather than bundled JSON so the ground truth is checked by the compiler,
/// and split by genre so no single file has to hold fifteen stories.
enum StoryLibrary {
    static let all: [GuidedStory] = FolkTales.all + DomesticStories.all + Mysteries.all

    static func stories(in genre: Genre) -> [GuidedStory] {
        all.filter { $0.genre == genre }
    }

    static func story(id: String) -> GuidedStory? {
        all.first { $0.id == id }
    }

    /// Named shortcuts, used by the test fixtures and the evaluation harness.
    static let thirdCast = FolkTales.thirdCast
    static let whatTheHouseKept = DomesticStories.whatTheHouseKept
    static let theNineFifteen = Mysteries.nineFifteen
}
