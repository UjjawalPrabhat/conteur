import Foundation
import SwiftData

/// A book the speaker is retelling. Everything for one title lives inside this
/// session — events, entity registry, progress — so continuity is just reading the
/// same record again.
@Model
final class BookSession {
    var idData: Data?
    var title: String
    var shapeRaw: String
    var startedAt: Date
    var lastSessionNumber: Int
    var recentSummaryData: Data?

    @Relationship(deleteRule: .cascade, inverse: \BookEvent.book)
    var events: [BookEvent]

    var entityRegistryData: Data?

    init(
        title: String,
        shape: StoryShape = .episodic,
        startedAt: Date = .now,
        lastSessionNumber: Int = 0,
        events: [BookEvent] = [],
        entityRegistry: [EntityRecord] = []
    ) {
        self.title = title
        self.shapeRaw = shape.rawValue
        self.startedAt = startedAt
        self.lastSessionNumber = lastSessionNumber
        self.recentSummaryData = nil
        self.events = events
        self.entityRegistryData = try? JSONEncoder().encode(entityRegistry)
    }

    var bookID: UUID {
        get {
            guard let data = idData,
                  let uuid = try? JSONDecoder().decode(UUID.self, from: data)
            else { return UUID() }
            return uuid
        }
        set { idData = try? JSONEncoder().encode(newValue) }
    }

    var shape: StoryShape {
        get { StoryShape(rawValue: shapeRaw) ?? .episodic }
        set { shapeRaw = newValue.rawValue }
    }

    var entityRegistry: [EntityRecord] {
        get {
            guard let data = entityRegistryData,
                  let records = try? JSONDecoder().decode([EntityRecord].self, from: data)
            else { return [] }
            return records
        }
        set {
            entityRegistryData = try? JSONEncoder().encode(newValue)
        }
    }

    var recentSummaries: [SessionSummary] {
        get {
            guard let data = recentSummaryData,
                  let summaries = try? JSONDecoder().decode([SessionSummary].self, from: data)
            else { return [] }
            return summaries
        }
        set {
            recentSummaryData = try? JSONEncoder().encode(newValue)
        }
    }

    var progress: ReadingProgress {
        let known = Set(entityRegistry.map { $0.name })
        let stakes = events.contains { $0.kind == .stakesStated }
        return ReadingProgress(
            previousSessions: lastSessionNumber,
            coveredComponents: [],
            stakesEstablished: stakes,
            knownEntities: known
        )
    }
}

/// One immutable observation about the book or the retelling. Events are append-only
/// so history never rewrites itself.
@Model
final class BookEvent {
    var idData: Data?
    var sessionNumber: Int
    var timestamp: TimeInterval
    var kindRaw: String
    var subject: String
    var detailText: String
    var evidenceStart: TimeInterval?
    var book: BookSession?

    init(
        id: UUID = UUID(),
        sessionNumber: Int,
        timestamp: TimeInterval,
        kind: EventKind,
        subject: String,
        detailText: String,
        evidenceStart: TimeInterval? = nil
    ) {
        self.idData = try? JSONEncoder().encode(id)
        self.sessionNumber = sessionNumber
        self.timestamp = timestamp
        self.kindRaw = kind.rawValue
        self.subject = subject
        self.detailText = detailText
        self.evidenceStart = evidenceStart
    }

    var id: UUID {
        get {
            guard let data = idData,
                  let uuid = try? JSONDecoder().decode(UUID.self, from: data)
            else { return UUID() }
            return uuid
        }
        set { idData = try? JSONEncoder().encode(newValue) }
    }

    var kind: EventKind {
        get { EventKind(rawValue: kindRaw) ?? .entityReferenced }
        set { kindRaw = newValue.rawValue }
    }

    var description: String {
        get { detailText }
        set { detailText = newValue }
    }
}

enum EventKind: String, Sendable, Hashable, Codable {
    case entityIntroduced
    case entityReferenced
    case componentCovered
    case stakesStated
    case emotionalMatch
    case emotionalMismatch
    case emotionalAdjacent
}

struct EntityRecord: Identifiable, Sendable, Codable, Hashable {
    let id: UUID
    let name: String
    let introducedInSession: Int
    let firstAppearanceDescription: String
    var lastMentionedSession: Int
    var mentionCount: Int
    var emotionalAssociations: [EmotionAssociation]

    init(
        id: UUID = UUID(),
        name: String,
        introducedInSession: Int,
        firstAppearanceDescription: String,
        lastMentionedSession: Int,
        mentionCount: Int = 1,
        emotionalAssociations: [EmotionAssociation] = []
    ) {
        self.id = id
        self.name = name
        self.introducedInSession = introducedInSession
        self.firstAppearanceDescription = firstAppearanceDescription
        self.lastMentionedSession = lastMentionedSession
        self.mentionCount = mentionCount
        self.emotionalAssociations = emotionalAssociations
    }
}

struct EmotionAssociation: Sendable, Codable, Hashable {
    let session: Int
    let emotion: DetectedEmotion
    let context: String
}

struct SessionSummary: Sendable, Codable, Hashable {
    let sessionNumber: Int
    let recordedAt: Date
    let focusDimension: Dimension?
    let verdictLabel: String?
    let note: String
}
