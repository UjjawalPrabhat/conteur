import Foundation

/// Everything one retelling produced: what was measured, what it means, and what to
/// say about it.
struct Assessment: Sendable {
    let recordedAt: Date
    let timeline: FeatureTimeline
    let narrative: NarrativeReading
    let diagnosis: Diagnosis
    let feedback: Feedback?
    /// Present only on a second telling.
    let progress: RetellingProgress?

    var focus: Dimension? { diagnosis.focus?.dimension }

    /// Contributes this retelling's scores to a speaker's rolling baseline.
    var scores: [Dimension: Double] {
        diagnosis.assessments.reduce(into: [:]) { partial, assessment in
            partial[assessment.dimension] = assessment.score
        }
    }
}
