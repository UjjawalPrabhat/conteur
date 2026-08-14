import Foundation

enum PauseKind: String, Sendable, Hashable, CaseIterable {
    case syntactic
    case hesitation
    case dramatic
    case stall
}

struct Pause: Sendable, Hashable {
    let kind: PauseKind
    let start: TimeInterval
    let duration: TimeInterval
}

struct FilledPause: Sendable, Hashable {
    let token: String
    let at: TimeInterval
}

struct Restart: Sendable, Hashable {
    let phrase: String
    let at: TimeInterval
}

struct DeliverySignals: Sendable, Hashable {
    let wordCount: Int
    let duration: TimeInterval
    let wordsPerMinute: Double
    let pauses: [Pause]
    let filledPauses: [FilledPause]
    let restarts: [Restart]

    static let empty = DeliverySignals(
        wordCount: 0,
        duration: 0,
        wordsPerMinute: 0,
        pauses: [],
        filledPauses: [],
        restarts: []
    )

    /// Rate rather than count: someone who speaks 3,000 words naturally produces
    /// more fillers than someone who speaks 500.
    var filledPauseRate: Double {
        wordCount > 0 ? Double(filledPauses.count) / Double(wordCount) : 0
    }

    func pauses(of kind: PauseKind) -> [Pause] {
        pauses.filter { $0.kind == kind }
    }
}
