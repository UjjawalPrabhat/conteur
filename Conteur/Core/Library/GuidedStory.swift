import Foundation

enum StoryComponent: String, Sendable, Hashable, CaseIterable, Codable {
    case setting
    case initiatingEvent
    case goal
    case conflict
    case attempts
    case consequences
    case resolution

}

/// Genre sets what a listener expects to hear back, so it replaces the shape the model
/// used to have to infer from the retelling itself.
enum Genre: String, Sendable, Codable, Hashable, CaseIterable {
    case folkTale
    case domestic
    case mystery

    var label: String {
        switch self {
        case .folkTale: "Folk tale"
        case .domestic: "Domestic"
        case .mystery: "Mystery"
        }
    }

    var expectedComponents: Set<StoryComponent> {
        switch self {
        case .folkTale:
            [.setting, .initiatingEvent, .attempts, .consequences, .resolution]
        case .domestic:
            [.setting, .initiatingEvent, .goal, .conflict, .consequences]
        case .mystery:
            [.setting, .initiatingEvent, .conflict, .attempts, .resolution]
        }
    }
}

enum EntityImportance: String, Sendable, Codable, Hashable {
    /// Leaving them out breaks the story.
    case central
    case supporting
    /// Leaving them out costs nothing; dwelling on them is padding.
    case incidental
}

struct StoryEntity: Sendable, Codable, Hashable {
    let name: String
    /// Other ways a reader might refer to them. Retellings almost never reuse the exact
    /// noun, so matching on the name alone badly under-counts what was mentioned.
    let aliases: [String]
    let importance: EntityImportance

    var surfaceForms: [String] { [name] + aliases }
}

/// One event in the story as written, annotated by hand.
///
/// `loadBearing` and `causedBy` are the two fields that matter most: authored, they turn
/// relevance and causal structure from a small model's opinion into a measurement.
struct CanonicalBeat: Sendable, Codable, Hashable, Identifiable {
    /// Also its position in the canonical order, from 1.
    let id: Int
    let component: StoryComponent
    let summary: String
    let loadBearing: Bool
    let entities: [String]
    /// The beat that caused this one, if any.
    let causedBy: Int?
    /// The moment the story turns on. Authored rather than guessed, so pace and
    /// expression can be checked at exactly the point that deserved room.
    let isClimax: Bool

    init(
        id: Int,
        component: StoryComponent,
        summary: String,
        loadBearing: Bool,
        entities: [String],
        causedBy: Int?,
        isClimax: Bool = false
    ) {
        self.id = id
        self.component = component
        self.summary = summary
        self.loadBearing = loadBearing
        self.entities = entities
        self.causedBy = causedBy
        self.isClimax = isClimax
    }
}

struct GuidedStory: Sendable, Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let genre: Genre
    /// Roughly how demanding it is: 1 is a single episode with few characters.
    let level: Int
    let prose: String
    let beats: [CanonicalBeat]
    let cast: [StoryEntity]
    /// What is at risk, in the author's words.
    ///
    /// Labov treated evaluation — why the story was worth telling — as what separates a
    /// story from a report. Supplying it means asking whether the reader conveyed *this*,
    /// rather than whether they happened to say anything evaluative at all.
    let stakes: String
}

extension GuidedStory {
    /// Adult silent reading of fiction runs around 260 words a minute (Brysbaert 2019
    /// meta-analysis), with wide individual variation.
    static let readingWordsPerMinute = 260.0

    /// Adults recall roughly a third to a half of a narrative's length on immediate free
    /// recall, which is what a retelling is.
    static let recallRatio = 0.33...0.5

    var wordCount: Int {
        prose.split(whereSeparator: \.isWhitespace).count
    }

    var readingTime: TimeInterval {
        Double(wordCount) / Self.readingWordsPerMinute * 60
    }

    /// How long a retelling of this story should be expected to run, before it counts as
    /// either skeletal or padded.
    var expectedRetellingWords: ClosedRange<Int> {
        let low = Int(Double(wordCount) * Self.recallRatio.lowerBound)
        let high = Int(Double(wordCount) * Self.recallRatio.upperBound)
        return low...high
    }

    var loadBearingBeats: [CanonicalBeat] {
        beats.filter(\.loadBearing)
    }

    var climax: CanonicalBeat? {
        beats.first(where: \.isClimax)
    }

    var centralCast: [StoryEntity] {
        cast.filter { $0.importance == .central }
    }

    /// Components the story actually contains, which is what coverage is measured against
    /// rather than what the genre would lead a listener to expect.
    var presentComponents: Set<StoryComponent> {
        Set(beats.map(\.component))
    }

    func beat(_ id: Int) -> CanonicalBeat? {
        beats.first { $0.id == id }
    }

    func entity(named name: String) -> StoryEntity? {
        cast.first { $0.name == name }
    }
}
