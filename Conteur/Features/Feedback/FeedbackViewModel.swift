import Foundation
import Observation

@MainActor
@Observable
final class FeedbackViewModel {
    let assessment: Assessment

    /// The passage the reader has been sent to, so it can be picked out from the rest.
    private(set) var highlighted: TimeInterval?

    init(assessment: Assessment) {
        self.assessment = assessment
    }

    var feedback: Feedback? { assessment.feedback }

    var bands: [DimensionAssessment] {
        assessment.diagnosis.assessments.sorted { $0.dimension.rawValue < $1.dimension.rawValue }
    }

    /// The retelling split at the moments it reached each of the story's events, so every
    /// stretch can be shown against what it was telling.
    var passages: [Passage] {
        let transcript = assessment.timeline.transcript
        guard !transcript.words.isEmpty else { return [] }

        let end = (transcript.words.last?.end ?? 0) + 0.01
        let covered = assessment.comparison.covered
        guard !covered.isEmpty else {
            return [Passage(start: 0, end: end, beat: nil, text: transcript.text)]
        }

        var passages: [Passage] = []
        // Anything said before the first recognised event still belongs to the retelling.
        if let opening = covered.first, opening.at > 0 {
            passages.append(passage(from: 0, to: opening.at, beat: nil))
        }
        for (index, coverage) in covered.enumerated() {
            let next = index + 1 < covered.count ? covered[index + 1].at : end
            passages.append(passage(from: coverage.at, to: next, beat: coverage.beat))
        }
        return passages.filter { !$0.text.isEmpty }
    }

    /// Which passage a moment falls in, so a finding can point at the words it came from
    /// rather than just naming a time.
    func passage(covering time: TimeInterval) -> Passage? {
        passages.first { time >= $0.start && time < $0.end } ?? passages.first
    }

    func reveal(_ time: TimeInterval) {
        highlighted = passage(covering: time)?.start
    }

    private func passage(from start: TimeInterval, to end: TimeInterval, beat: CanonicalBeat?) -> Passage {
        Passage(
            start: start,
            end: end,
            beat: beat,
            text: assessment.timeline.words(in: start..<end).map(\.text).joined(separator: " ")
        )
    }

    struct Passage: Identifiable {
        let start: TimeInterval
        let end: TimeInterval
        /// The story event this stretch told, when it told one.
        let beat: CanonicalBeat?
        let text: String

        var id: TimeInterval { start }
    }
}
