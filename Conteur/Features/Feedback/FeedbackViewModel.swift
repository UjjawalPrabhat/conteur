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

    var readingProgress: ReadingProgress { assessment.readingProgress }

    var bands: [DimensionAssessment] {
        assessment.diagnosis.assessments.sorted { $0.dimension.rawValue < $1.dimension.rawValue }
    }

    var allFindings: [Dimension: [Finding]] {
        var grouped: [Dimension: [Finding]] = [:]
        for assessment in assessment.diagnosis.assessments {
            guard !assessment.findings.isEmpty else { continue }
            grouped[assessment.dimension] = assessment.findings
        }
        return grouped
    }

    var deliverySignals: DeliverySignals { assessment.timeline.delivery }

    struct BeatDetail: Identifiable {
        let id: Int
        let beat: Beat
        let text: String
    }

    var beatDetails: [BeatDetail] {
        assessment.narrative.beats.enumerated().map { index, beat in
            BeatDetail(
                id: index,
                beat: beat,
                text: assessment.timeline.words(in: beat.start..<beat.end)
                    .map(\.text)
                    .joined(separator: " ")
            )
        }
    }

    /// The retelling split into the stretches it was labelled in.
    var passages: [Passage] {
        assessment.narrative.beats.map { beat in
            Passage(
                start: beat.start,
                end: beat.end,
                kind: beat.kind,
                text: assessment.timeline.words(in: beat.start..<beat.end)
                    .map(\.text)
                    .joined(separator: " ")
            )
        }
    }

    /// Which passage a moment falls in, so a finding can point at the words it came from
    /// rather than just naming a time.
    func passage(covering time: TimeInterval) -> Passage? {
        passages.first { time >= $0.start && time < $0.end } ?? passages.first
    }

    func reveal(_ time: TimeInterval) {
        highlighted = passage(covering: time)?.start
    }

    struct Passage: Identifiable {
        let start: TimeInterval
        let end: TimeInterval
        let kind: SpanKind
        let text: String

        var id: TimeInterval { start }
    }
}
