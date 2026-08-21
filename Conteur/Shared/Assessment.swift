import Foundation

/// Everything one retelling produced: what was measured, what it means, and what to
/// say about it.
struct Assessment: Sendable {
    let recordedAt: Date
    let timeline: FeatureTimeline
    let narrative: NarrativeReading
    let diagnosis: Diagnosis
    let feedback: Feedback?
    let progress: RetellingProgress?
    let readingProgress: ReadingProgress
    let bookID: UUID?
    var mode: ChallengeMode? = nil

    var focus: Dimension? { diagnosis.focus?.dimension }

    var scores: [Dimension: Double] {
        diagnosis.assessments.reduce(into: [:]) { partial, assessment in
            partial[assessment.dimension] = assessment.score
        }
    }
}

// MARK: - Comparison types

// Comparison types are intentionally defined alongside their logic in
// `RetellingComparison.swift` so the retry mechanics stay together.
