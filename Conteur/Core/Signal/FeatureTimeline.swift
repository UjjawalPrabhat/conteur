import Foundation

/// Every measurement from one retelling, aligned on a single clock.
///
/// Audio, transcript, and face each start their own clock at capture, so alignment is
/// accurate to tens of milliseconds rather than exactly. Every consumer reasons over
/// windows of seconds, where that error does not matter.
struct FeatureTimeline: Sendable {
    let transcript: Transcript
    let delivery: DeliverySignals
    let prosody: [ProsodyFrame]
    let expressivity: [ExpressivityWindow]

    static let empty = FeatureTimeline(
        transcript: .empty,
        delivery: .empty,
        prosody: [],
        expressivity: []
    )

    var duration: TimeInterval { transcript.duration }
}

extension FeatureTimeline {
    private var voicedPitches: [Float] {
        prosody.compactMap(\.pitch)
    }

    /// Coefficient of variation, so the figure is comparable between a low voice and a
    /// high one rather than tracking absolute pitch.
    var pitchVariation: Float {
        let pitches = voicedPitches
        guard pitches.count > 1 else { return 0 }
        let mean = pitches.reduce(0, +) / Float(pitches.count)
        guard mean > 0 else { return 0 }
        let variance = pitches.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(pitches.count)
        return sqrt(variance) / mean
    }

    var dynamicRange: Float {
        let levels = prosody.map(\.loudness).filter { $0 > 0 }
        guard let quietest = levels.min(), let loudest = levels.max(), quietest > 0 else { return 0 }
        return loudest / quietest
    }

    func wordsPerMinute(in range: Range<TimeInterval>) -> Double {
        let words = transcript.words.filter { range.contains($0.start) }
        let span = range.upperBound - range.lowerBound
        guard span > 0, !words.isEmpty else { return 0 }
        return Double(words.count) / span * 60
    }

    func expressivity(at time: TimeInterval) -> Float? {
        expressivity.first { time >= $0.start && time < $0.end }?.variation
    }

    /// Windows where the face barely moved, paired with what was being said.
    func flatExpressionWindows(below threshold: Float) -> [ExpressivityWindow] {
        expressivity.filter { $0.variation < threshold }
    }

    func words(in range: Range<TimeInterval>) -> [SpokenWord] {
        transcript.words.filter { range.contains($0.start) }
    }
}
