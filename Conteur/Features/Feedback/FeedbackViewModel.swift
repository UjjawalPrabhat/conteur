import Foundation
import Observation

@MainActor
@Observable
final class FeedbackViewModel {
    /// Long enough to hear the moment in context, short enough that tapping the next
    /// piece of evidence doesn't mean sitting through the rest of the recording.
    private static let excerpt: TimeInterval = 8

    let assessment: Assessment

    /// Which moment is playing, so the row that was tapped can show it.
    private(set) var playing: TimeInterval?

    private let player: any Playing
    private var playback: Task<Void, Never>?

    init(assessment: Assessment, player: any Playing = RecordingPlayer()) {
        self.assessment = assessment
        self.player = player
    }

    var feedback: Feedback? { assessment.feedback }

    var bands: [DimensionAssessment] {
        assessment.diagnosis.assessments.sorted { $0.dimension.rawValue < $1.dimension.rawValue }
    }

    /// Words grouped so the transcript can be read back in the stretches it was
    /// labelled in, with each one's moment available for playback.
    var passages: [Passage] {
        assessment.narrative.beats.map { beat in
            Passage(
                start: beat.start,
                kind: beat.kind,
                text: assessment.timeline.words(in: beat.start..<beat.end)
                    .map(\.text)
                    .joined(separator: " ")
            )
        }
    }

    func isPlaying(_ time: TimeInterval) -> Bool {
        playing == time
    }

    func replay(from time: TimeInterval) {
        playback?.cancel()

        guard playing != time else {
            stopReplay()
            return
        }

        playing = time
        playback = Task {
            do {
                let remaining = try await player.play(assessment.audio, from: time)
                try await Task.sleep(for: .seconds(min(Self.excerpt, remaining)))
            } catch {
                // Cancellation is the ordinary case here — another row was tapped.
            }
            await player.stop()
            if !Task.isCancelled { playing = nil }
        }
    }

    func stopReplay() {
        playback?.cancel()
        playback = nil
        playing = nil
        Task { await player.stop() }
    }

    struct Passage: Identifiable {
        let start: TimeInterval
        let kind: SpanKind
        let text: String

        var id: TimeInterval { start }
    }
}
