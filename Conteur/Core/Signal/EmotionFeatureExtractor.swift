import Foundation

/// Converts expression samples into feature vectors suitable for the emotion model.
///
/// The current implementation produces a simple coefficient summary so the
/// emotion pipeline has a real audio path while the full mel-spectrogram + Core
/// ML model is still being integrated.
struct EmotionFeatureExtractor: Sendable {
    static let sampleRate: Double = 16_000
    static let frameSize: Int = 512
    static let hopSize: Int = 256

    func features(from sample: ExpressionSample) -> [Float]? {
        let rms = sample.coefficients.values.reduce(0, +) / Float(max(sample.coefficients.count, 1))
        let zcr = sample.coefficients.values.reduce(0) { max($0, abs($1)) }
        let centroid = sample.coefficients.values.reduce(0, +) / Float(max(sample.coefficients.count, 1))
        return [rms, zcr, centroid]
    }
}
