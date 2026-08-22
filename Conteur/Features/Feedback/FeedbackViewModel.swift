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

    var note: String {
        feedback?.note ?? "There wasn't enough in that one for me to say much about how you told it."
    }

    var challenge: String {
        feedback?.challenge ?? "Tell it again, and give it a bit more room this time."
    }

    /// The line under the title: which story, whether this was a retell, and what it came to.
    var subtitle: String {
        let transcript = assessment.timeline.transcript
        var parts = [assessment.comparison.story.title]
        if assessment.progress != nil { parts.append("second telling") }
        parts.append("\(transcript.words.count) words")
        parts.append(transcript.duration.secondsLabel)
        return parts.joined(separator: " · ")
    }

    var spokenDuration: String {
        assessment.timeline.transcript.duration.timestampLabel
    }

    /// How many dimensions held, on the closed row.
    ///
    /// The design's "2 changed" would need the previous telling's six bands, and only the
    /// focus dimension's before-and-after is carried through. Counting what is Strong now is
    /// the honest version of the same glance.
    var strongLabel: String {
        let strong = bands.count { $0.band == .strong }
        return strong == 0 ? "none Strong" : "\(strong) Strong"
    }

    /// Moments in the retelling the feedback is about — these can be pointed at.
    var located: [Detail] { details.filter(\.evidence.isLocated) }

    /// Things the story had that the retelling did not. There is no moment to point at,
    /// so these are shown as absences rather than as places.
    var absences: [Detail] { details.filter { !$0.evidence.isLocated } }

    /// Each piece of evidence beside the finding that produced it.
    ///
    /// The composed feedback carries evidence alone, which is all the spoken note needs. The
    /// screen needs more: what kind of claim this is, and the measured sentence behind it.
    /// Both are on the finding, so the finding is looked back up rather than copied into
    /// `Feedback` where the composer could then be tempted to edit it.
    private var details: [Detail] {
        let findings = assessment.diagnosis.assessments.flatMap(\.findings)
        return (feedback?.evidence ?? []).enumerated().map { index, evidence in
            let source = findings.first { $0.evidence.contains(evidence) }
            return Detail(
                id: index,
                evidence: evidence,
                dimension: source?.dimension ?? feedback?.dimension ?? .structure,
                observation: source?.observation
            )
        }
    }

    struct Detail: Identifiable {
        let id: Int
        let evidence: Evidence
        /// Shown as the card's category, so a reader can tell a delivery measurement from a
        /// fidelity one without reading the sentence first.
        let dimension: Dimension
        let observation: String?
    }

    var bands: [DimensionAssessment] {
        assessment.diagnosis.assessments.sorted { $0.dimension.rawValue < $1.dimension.rawValue }
    }

    /// The retelling split at the moments it reached each of the story's events, so every
    /// stretch can be shown against what it was telling.
    var passages: [Passage] {
        let transcript = assessment.timeline.transcript
        guard !transcript.words.isEmpty else { return [] }

        let end = (transcript.words.last?.end ?? 0) + 0.01
        let covered = assessment.comparison.located
        guard !covered.isEmpty else {
            return [Passage(start: 0, end: end, beat: nil, text: transcript.text)]
        }

        var passages: [Passage] = []
        // Anything said before the first recognised event still belongs to the retelling.
        if let first = covered.first?.at, first > 0 {
            passages.append(passage(from: 0, to: first, beat: nil))
        }
        for (index, coverage) in covered.enumerated() {
            guard let start = coverage.at else { continue }
            let next = index + 1 < covered.count ? (covered[index + 1].at ?? end) : end
            passages.append(passage(from: start, to: next, beat: coverage.beat))
        }
        return passages.filter { !$0.text.isEmpty }
    }

    /// Which passage a moment falls in, so a finding can point at the words it came from
    /// rather than just naming a time.
    func passage(covering time: TimeInterval) -> Passage? {
        passages.first { time >= $0.start && time < $0.end } ?? passages.first
    }

    func reveal(_ time: TimeInterval?) {
        guard let time else { return }
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
