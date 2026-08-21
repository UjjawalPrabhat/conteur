import Foundation

struct Feedback: Sendable, Hashable {
    let dimension: Dimension
    /// Three or four sentences, spoken aloud and shown as text.
    let note: String
    /// What to do differently on the next attempt.
    let challenge: String
    let evidence: [Evidence]

    static let none = Feedback(dimension: .structure, note: "", challenge: "", evidence: [])
}

protocol FeedbackComposing: Sendable {
    /// Phrases an already-decided finding. Composers must not introduce claims that
    /// are not in the diagnosis — every sentence has to trace back to a measurement.
    func compose(from diagnosis: Diagnosis, context: TargetedContext?, history: Band?, progress: RetellingProgress?) async -> Feedback?
}

extension FeedbackComposing {
    func compose(from diagnosis: Diagnosis, history: Band?, progress: RetellingProgress?) async -> Feedback? {
        await compose(from: diagnosis, context: nil, history: history, progress: progress)
    }
}
