import Foundation

/// Every measurement from one retelling, aligned on a single clock.
///
/// Audio and transcript each start their own clock at capture, so alignment is accurate to
/// tens of milliseconds rather than exactly. Every consumer reasons over windows of seconds,
/// where that error does not matter.
struct FeatureTimeline: Sendable {
    let transcript: Transcript
    let delivery: DeliverySignals
    let prosody: [ProsodyFrame]

    static let empty = FeatureTimeline(
        transcript: .empty,
        delivery: .empty,
        prosody: []
    )

    var duration: TimeInterval { transcript.duration }
}

extension FeatureTimeline {
    private var voicedPitches: [Float] {
        prosody.compactMap(\.pitch)
    }

    /// How much the voice moved, as the standard deviation of pitch in **semitones**.
    ///
    /// Semitones rather than hertz because pitch is heard logarithmically: a 20 Hz move is
    /// wide at the bottom of a low voice and inaudible at the top of a high one. A coefficient
    /// of variation over raw hertz — which this was — divides out the mean but keeps the linear
    /// scale, so the same heard expressiveness scored differently from voice to voice. This is
    /// the measure the prosody literature uses, and it makes the threshold comparable across
    /// speakers instead of only within one.
    var pitchVariationInSemitones: Float {
        // log2 of a non-positive pitch is undefined, and an unvoiced frame has no pitch to
        // convert — both are already excluded, but the guard keeps that a local fact.
        let semitones = voicedPitches.filter { $0 > 0 }.map { 12 * log2($0) }
        guard semitones.count > 1 else { return 0 }

        let mean = semitones.reduce(0, +) / Float(semitones.count)
        let variance = semitones.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(semitones.count)
        return sqrt(variance)
    }

    func wordsPerMinute(in range: Range<TimeInterval>) -> Double {
        let words = transcript.words.filter { range.contains($0.start) }
        let span = range.upperBound - range.lowerBound
        guard span > 0, !words.isEmpty else { return 0 }
        return Double(words.count) / span * 60
    }

    func words(in range: Range<TimeInterval>) -> [SpokenWord] {
        transcript.words.filter { range.contains($0.start) }
    }
}
