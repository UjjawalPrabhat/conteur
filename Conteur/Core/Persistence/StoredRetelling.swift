import Foundation
import SwiftData

/// One retelling, kept so progress means something across months.
///
/// Deliberately flat, with attempts linked by `groupID` rather than a relationship:
/// CloudKit requires every property to be optional or defaulted and forbids unique
/// constraints, and a flat record satisfies that without ceremony.
@Model
final class StoredRetelling {
    var recordedAt: Date = Date.distantPast
    var groupID: UUID?
    /// 1 for the first telling, 2 for the retell against the challenge.
    var attempt: Int = 1
    /// Set on the fixed prompt that is retold periodically, so progress is measured
    /// against constant difficulty rather than whatever was read that week.
    var isBenchmark: Bool = false

    /// Which story was told. Kept as text rather than an id: the record has to stay
    /// readable if the library ever changes underneath it.
    var storyTitle: String?
    var focus: String?
    var note: String?
    var challenge: String?
    /// Per-dimension scores, encoded because SwiftData cannot store a dictionary.
    var scoreData: Data?
    /// What was said. The only record of a retelling that outlives the session — audio
    /// is transcribed as it arrives and never written anywhere.
    var transcriptText: String?

    var wordCount: Int = 0
    var duration: TimeInterval = 0

    init(
        recordedAt: Date = Date.distantPast,
        groupID: UUID? = nil,
        attempt: Int = 1,
        isBenchmark: Bool = false,
        storyTitle: String? = nil,
        focus: String? = nil,
        note: String? = nil,
        challenge: String? = nil,
        scoreData: Data? = nil,
        transcriptText: String? = nil,
        wordCount: Int = 0,
        duration: TimeInterval = 0
    ) {
        self.recordedAt = recordedAt
        self.groupID = groupID
        self.attempt = attempt
        self.isBenchmark = isBenchmark
        self.storyTitle = storyTitle
        self.focus = focus
        self.note = note
        self.challenge = challenge
        self.scoreData = scoreData
        self.transcriptText = transcriptText
        self.wordCount = wordCount
        self.duration = duration
    }
}

extension StoredRetelling {
    var scores: [Dimension: Double] {
        guard let scoreData else { return [:] }
        return (try? JSONDecoder().decode([Dimension: Double].self, from: scoreData)) ?? [:]
    }

    var focusDimension: Dimension? {
        focus.flatMap(Dimension.init(rawValue:))
    }
}
