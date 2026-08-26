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

/// What kind of story this is — how the library is grouped, and what the Progress tab
/// tallies by.
///
/// `expectedComponents` is an authoring contract rather than a production input: no rule
/// reads it, and `StoryLibraryTests` uses it to check that every story written for a genre
/// actually carries the beats that genre implies. Coverage is always measured against the
/// beats a story really has.
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

    /// A concrete, one-sentence preview of the story's core premise and hook.
    var synopsis: String {
        switch id {
        case "third-cast":
            return "A fisherman catches a speaking fish that grants his wishes, but asking for the sea itself costs him everything."
        case "salt-road":
            return "A young woman trades her voice for safe passage, only to discover the road's danger was an old myth."
        case "coat-of-nine-winters":
            return "A magical coat shields a boy from grief and cold, but holds nine years of sorrow waiting for him."
        case "what-the-miller-owed":
            return "A desperate miller clears his mounting debts by trading away his young apprentice's indenture."
        case "lantern-keeper":
            return "A lighthouse keeper investigates the one night her father left the lantern dark and discovers a tragic secret."
        case "what-the-house-kept":
            return "Clearing her late mother's home, a daughter uncovers sixty returned letters to an aunt she never knew."
        case "second-kitchen":
            return "A grieving widower rebuilds his kitchen to match his late wife's, unknowingly driving his daughter away."
        case "long-way-round":
            return "Driving his father to a critical hospital scan, a son takes a coastal detour to share precious silent time."
        case "nobodys-fault":
            return "A broken hallway shelf triggers a heated argument that uncovers a couple's unspoken truths."
        case "tuesdays-chair":
            return "A woman continues going to a support group she no longer needs to keep a comforting chair open for newcomers."
        case "the-nine-fifteen", "nine-fifteen":
            return "A daily commuter follows a mysterious passenger carrying different briefcases and learns his touching purpose."
        case "wrong-umbrella":
            return "Picking up the wrong library umbrella leads a woman to a stranger connected to her brother's drowning."
        case "room-four-b":
            return "A hotel cleaner discovers an unslept bed and quietly leaves extra comforts for a struggling guest."
        case "meter-reading":
            return "An unexplained power bill in an empty house reveals a year of freezer meals lovingly prepared by an ailing father."
        case "cyclist-on-ferndale":
            return "A driver investigates an erratic cyclist, only to discover he was deliberately slowing cars near a school."
        default:
            return stakes
        }
    }
}
