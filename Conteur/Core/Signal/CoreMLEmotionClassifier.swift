import CoreML
import Foundation

/// Core ML-backed emotion classifier.
///
/// The current implementation includes the model-loading path and inference
/// interface, but falls back to a stub prediction when no model is bundled yet.
/// Replace the stub with a real `emotion2vec+` INT8 `.mlpackage` to enable
/// live audio emotion inference.
struct CoreMLEmotionClassifier: Sendable {
    private let model: EmotionModelWrapper?

    init(model: EmotionModelWrapper? = nil) {
        self.model = model
    }

    func probabilities(from features: [Float]) -> [String: Double]? {
        guard let model else { return stubProbabilities() }
        return model.predict(features: features)
    }

    private func stubProbabilities() -> [String: Double]? {
        // No model bundled yet. Return a neutral placeholder so the rest of the
        // pipeline remains testable without a real inference artifact.
        return ["neutral": 0.75]
    }
}

protocol EmotionModelWrapper: Sendable {
    func predict(features: [Float]) -> [String: Double]?
}
