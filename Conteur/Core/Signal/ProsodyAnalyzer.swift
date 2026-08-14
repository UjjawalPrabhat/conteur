import Accelerate
import AVFoundation

struct ProsodyFrame: Sendable, Hashable {
    let at: TimeInterval
    let loudness: Float
    /// Fundamental frequency in Hz, or `nil` where the audio is unvoiced.
    let pitch: Float?
}

/// Extracts pitch and loudness from raw audio. The transcriber cannot supply either,
/// and both are needed to tell a story delivered flatly from one delivered well.
struct ProsodyAnalyzer: Sendable {
    /// Bounds of human speaking pitch. Searching outside this range finds harmonics
    /// and octave errors rather than the fundamental.
    private static let lowestPitch: Double = 70
    private static let highestPitch: Double = 350

    /// Below this correlation the strongest lag is noise, not a repeating waveform,
    /// which means the frame is unvoiced — a breath or a consonant, not a vowel.
    private static let voicingThreshold: Float = 0.3

    /// Runs the analysis off the main actor, since pitch detection is the most
    /// expensive per-chunk work in the pipeline.
    func frames(from chunks: AsyncStream<AudioChunk>) -> AsyncStream<ProsodyFrame> {
        AsyncStream { continuation in
            let work = Task.detached {
                for await chunk in chunks {
                    if let frame = frame(from: chunk) {
                        continuation.yield(frame)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }

    func frame(from chunk: AudioChunk) -> ProsodyFrame? {
        guard let samples = chunk.buffer.floatChannelData?[0] else { return nil }
        let count = Int(chunk.buffer.frameLength)
        guard count > 0 else { return nil }

        var meanSquare: Float = 0
        vDSP_measqv(samples, 1, &meanSquare, vDSP_Length(count))

        return ProsodyFrame(
            at: chunk.start,
            loudness: sqrt(meanSquare),
            pitch: pitch(in: samples, count: count, sampleRate: chunk.buffer.format.sampleRate)
        )
    }

    private func pitch(
        in samples: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> Float? {
        let shortestLag = Int(sampleRate / Self.highestPitch)
        let longestLag = Int(sampleRate / Self.lowestPitch)
        guard shortestLag > 0, longestLag < count else { return nil }

        var energy: Float = 0
        vDSP_dotpr(samples, 1, samples, 1, &energy, vDSP_Length(count))
        guard energy > 0 else { return nil }

        var strongestLag = 0
        var strongestCorrelation: Float = 0
        for lag in shortestLag...longestLag {
            var correlation: Float = 0
            vDSP_dotpr(samples, 1, samples + lag, 1, &correlation, vDSP_Length(count - lag))
            let normalized = correlation / energy
            if normalized > strongestCorrelation {
                strongestCorrelation = normalized
                strongestLag = lag
            }
        }

        guard strongestCorrelation > Self.voicingThreshold, strongestLag > 0 else { return nil }
        return Float(sampleRate / Double(strongestLag))
    }
}
