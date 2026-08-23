import Foundation

/// Everything one retelling produced: what was measured, what it means, and what to
/// say about it.
struct Assessment: Sendable {
    let recordedAt: Date
    let timeline: FeatureTimeline
    let comparison: SourceComparison
    let diagnosis: Diagnosis
    let feedback: Feedback?
    /// Present only on a second telling.
    let progress: RetellingProgress?

    var focus: Dimension? { diagnosis.focus?.dimension }

    /// Contributes this retelling's scores to a speaker's rolling baseline.
    ///
    /// Only the dimensions that could actually be judged. An unjudgeable dimension carries a
    /// score of 1 as a placeholder, and a placeholder that outlives the band it belongs to
    /// reads back as a perfect telling — which would put "not enough to tell" into the
    /// baseline, the tiers and the badges as though it were the best possible answer.
    var scores: [Dimension: Double] {
        diagnosis.assessments.reduce(into: [:]) { partial, assessment in
            guard assessment.band != .insufficient else { return }
            partial[assessment.dimension] = assessment.score
        }
    }

    /// What went wrong, by subject rather than by sentence. Kept so history can say which
    /// failure keeps recurring — the observations are phrased for one telling and read
    /// oddly in aggregate, where the subject is stable.
    var findingSubjects: [String] {
        diagnosis.assessments.flatMap(\.findings).map(\.subject)
    }
}
