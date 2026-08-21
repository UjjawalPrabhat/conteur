import Foundation
import SwiftData

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
            let values = history.compactMap { $0.scores[dimension] }
            guard !values.isEmpty else { return }
            partial[dimension] = values.reduce(0, +) / Double(values.count)
        }
        return Baseline(scores: scores)
    }

    func lastBand(for dimension: Dimension) -> Band? {
        recent(limit: 1).first?.scores[dimension].map(Band.init(score:))
    }

    func recent(limit: Int) -> [StoredRetelling] {
        var descriptor = FetchDescriptor<StoredRetelling>(
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func attempts(in group: UUID) -> [StoredRetelling] {
        let descriptor = FetchDescriptor<StoredRetelling>(
            predicate: #Predicate { $0.groupID == group },
            sortBy: [SortDescriptor(\.attempt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
