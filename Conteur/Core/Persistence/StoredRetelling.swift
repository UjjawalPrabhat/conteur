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

    var focus: String?
    var note: String?
    var challenge: String?
    /// Per-dimension scores, encoded because SwiftData cannot store a dictionary.
    var scoreData: Data?
    /// Filename only. Recordings stay on the device that made them and are never synced.
    var audioFilename: String?

    var wordCount: Int = 0
    var duration: TimeInterval = 0

    init(
        recordedAt: Date = Date.distantPast,
        groupID: UUID? = nil,
        attempt: Int = 1,
        isBenchmark: Bool = false,
        focus: String? = nil,
        note: String? = nil,
        challenge: String? = nil,
        scoreData: Data? = nil,
        audioFilename: String? = nil,
        wordCount: Int = 0,
        duration: TimeInterval = 0
    ) {
        self.recordedAt = recordedAt
        self.groupID = groupID
        self.attempt = attempt
        self.isBenchmark = isBenchmark
        self.focus = focus
        self.note = note
        self.challenge = challenge
        self.scoreData = scoreData
        self.audioFilename = audioFilename
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

    /// Recordings can be deleted or arrive from another device without their audio, so
    /// a stored retelling may have no playable file.
    var audio: URL? {
        audioFilename.map { URL.documentsDirectory.appending(path: $0) }
    }
}
