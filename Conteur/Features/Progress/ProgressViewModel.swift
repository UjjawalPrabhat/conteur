import Foundation
import Observation
import SwiftData

/// Reads history and hands the screens a finished report.
///
/// Everything it presents is computed by `ProgressReport`, which is pure. This exists only to
/// fetch and to format — no arithmetic lives here, so nothing the user reads is decided in a
/// place that cannot be tested.
@MainActor
@Observable
final class ProgressViewModel {
    private(set) var report = ProgressReport.empty

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func load() {
        let descriptor = FetchDescriptor<StoredRetelling>(
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )
        report = ProgressReport.over((try? context.fetch(descriptor)) ?? [])
    }

    var hasHistory: Bool { report.tellings > 0 }

    var tellingsLabel: String {
        report.tellings == 1 ? "1 telling" : "\(report.tellings) tellings"
    }

    var wordsLabel: String {
        report.wordsTold.formatted(.number)
    }

    /// Whole minutes. Seconds at the fire is a precision nobody asked for.
    var timeLabel: String {
        "\(Int((report.timeAtTheFire / 60).rounded()))m"
    }

    /// What the next level needs, phrased as the thing still to do rather than as a score.
    var nextLevel: String? {
        guard let next = report.standing.next else { return nil }
        guard let progress = report.standing.progress else {
            return "\(next.requirement.capitalizedFirst) reaches \(next.label)."
        }
        let remaining = max(0, progress.needed - progress.done)
        guard remaining > 0 else { return "\(next.requirement.capitalizedFirst) reaches \(next.label)." }
        return "\(remaining) more \(next.requirement.dropCountPrefix) reaches \(next.label)."
    }

    var badgesLabel: String {
        "\(report.badges.count) of \(Badge.all.count)"
    }

    var unearnedBadges: [Badge] {
        let earned = Set(report.badges.map(\.id))
        return Badge.all.filter { !earned.contains($0.id) }
    }

    var paceLabel: String? {
        report.pace.last.map { "\(Int($0.wordsPerMinute.rounded())) wpm" }
    }

    /// The two ends of the pace series, named in words. A chart with no axes needs them, and
    /// they are more use than an axis would be.
    var paceEnds: (earliest: String, latest: String)? {
        guard let first = report.pace.first, let last = report.pace.last, report.pace.count > 1
        else { return nil }
        return (
            "\(Int(first.wordsPerMinute.rounded())) in \(first.at.formatted(.dateTime.month(.wide)))",
            "\(Int(last.wordsPerMinute.rounded())) most recently"
        )
    }

    var bestHourLabel: String? {
        report.bestHour.map { String(format: "%02d:00", $0) }
    }
}

private extension String {
    /// `FireLevel.requirement` reads "five tellings with Engagement above Developing", which
    /// is right on its own and wrong after "4 more". This drops the leading count so both
    /// phrasings can come from one string.
    var dropCountPrefix: String {
        let words = split(separator: " ")
        guard let first = words.first, Int(first) != nil || spelledNumbers.contains(String(first))
        else { return self }
        return words.dropFirst().joined(separator: " ")
    }

    private var spelledNumbers: Set<String> {
        ["one", "two", "three", "four", "five", "six"]
    }
}
