import Foundation
import SwiftData

/// What the last few tellings say, for the one about to start: where this speaker usually
/// sits, and where the dimension they were challenged on stood last time.
struct Priming: Sendable, Hashable {
    let baseline: Baseline
    let history: Band?

    static let none = Priming(baseline: .none, history: nil)
}

@MainActor
struct SwiftDataRetellingStore {
    /// Enough history to smooth out one unusually good or bad day, short enough that
    /// improvement still moves the baseline.
    private static let baselineWindow = 8

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ assessment: Assessment, attempt: Int, group: UUID, isBenchmark: Bool) throws {
        let record = StoredRetelling(
            recordedAt: assessment.recordedAt,
            groupID: group,
            attempt: attempt,
            isBenchmark: isBenchmark,
            storyTitle: assessment.comparison.story.title,
            storyID: assessment.comparison.story.id,
            focus: assessment.focus?.rawValue,
            note: assessment.feedback?.note,
            challenge: assessment.feedback?.challenge,
            verdict: assessment.progress?.verdict.rawValue,
            scoreData: try? JSONEncoder().encode(assessment.scores),
            findingData: try? JSONEncoder().encode(assessment.findingSubjects),
            transcriptText: assessment.timeline.transcript.text,
            wordCount: assessment.timeline.delivery.wordCount,
            duration: assessment.timeline.duration
        )
        context.insert(record)
        try context.save()
    }

    func baseline() -> Baseline {
        let history = recent(limit: Self.baselineWindow)
        guard !history.isEmpty else { return .none }

        let scores = Dimension.allCases.reduce(into: [Dimension: Double]()) { partial, dimension in
            partial[dimension] = StoredRetelling.mean(of: history, for: dimension)
        }
        return Baseline(
            scores: scores.compactMapValues { $0 },
            standingFocus: history.first?.focusDimension
        )
    }

    /// Where the fire stands across all of history. Read either side of a save so a telling
    /// can be told it was the one that earned a level.
    func fireStanding() -> FireStanding {
        let descriptor = FetchDescriptor<StoredRetelling>(
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )
        return FireLevel.standing(over: (try? context.fetch(descriptor)) ?? [])
    }

    /// What a telling needs to know about the ones before it, in one read.
    ///
    /// Together because they are always wanted together, and because they are database reads:
    /// the screen that needs them is rebuilt often and must not fetch on every pass.
    func priming(focus: Dimension?) -> Priming {
        Priming(
            baseline: baseline(),
            history: focus.flatMap { lastBand(for: $0) }
        )
    }

    func lastBand(for dimension: Dimension) -> Band? {
        recent(limit: 1).first?.band(for: dimension)
    }

    func recent(limit: Int) -> [StoredRetelling] {
        var descriptor = FetchDescriptor<StoredRetelling>(
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
}
