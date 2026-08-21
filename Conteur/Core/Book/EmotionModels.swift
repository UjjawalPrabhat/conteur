import Foundation

struct EntityGrounding: Codable, Sendable, Hashable {
    let entity: String
    let status: EntityStatus
}

enum EntityStatus: String, Sendable, Codable, Hashable {
    case new
    case carried
    case ambiguous
}

enum DetectedEmotion: String, Sendable, Hashable, Codable, CaseIterable {
    case joy
    case sadness
    case anger
    case fear
    case surprise
    case tension
    case relief
    case neutral
}

struct EmotionReading: Sendable, Identifiable, Hashable {
    let id: UUID
    let emotion: DetectedEmotion
    let confidence: Double
    let alternatives: [DetectedEmotion: Double]

    init(id: UUID = UUID(), emotion: DetectedEmotion, confidence: Double, alternatives: [DetectedEmotion: Double] = [:]) {
        self.id = id
        self.emotion = emotion
        self.confidence = confidence
        self.alternatives = alternatives
    }
}

enum EmotionNoEvidence {
    case noEvidence
}

enum MatchResult: String, Sendable, Hashable, Codable {
    case matched
    case adjacent
    case mismatched

    var eventKind: EventKind {
        switch self {
        case .matched: return .emotionalMatch
        case .adjacent: return .emotionalAdjacent
        case .mismatched: return .emotionalMismatch
        }
    }
}

struct EmotionMatch: Sendable, Hashable {
    let beatStart: TimeInterval
    let expected: DetectedEmotion
    let actual: DetectedEmotion
    let result: MatchResult
    let description: String
}

struct TargetedContext: Hashable {
    let bookTitle: String
    let evaluationMode: ChallengeMode
    let entityEvents: [BookEvent]
    let emotionalHistory: [BookEvent]
    let stakesEvent: BookEvent?
    let componentEvents: [BookEvent]
}

enum ChallengeMode: String, Sendable, Hashable, Codable, CaseIterable {
    case continuation
    case standalone
}
