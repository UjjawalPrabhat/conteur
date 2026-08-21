import Foundation

/// Maps emotion2vec+ output to the app's storytelling emotion vocabulary.
struct EmotionClassifier: Sendable {
    private static let minimumConfidence: Double = 0.6

    private static let modelToApp: [String: DetectedEmotion] = [
        "angry": .anger,
        "disgusted": .neutral,
        "fearful": .fear,
        "happy": .joy,
        "neutral": .neutral,
        "other": .neutral,
        "sad": .sadness,
        "surprised": .surprise,
        "unknown": .neutral
    ]

    /// Returns nil when confidence is too low, signaling that the emotion evaluator
    /// should skip coaching rather than invent it.
    func reading(from probabilities: [String: Double]) -> DetectedEmotion? {
        guard let (modelEmotion, confidence) = probabilities.max(by: { $0.value < $1.value }) else { return nil }
        guard confidence >= Self.minimumConfidence else { return nil }
        return Self.modelToApp[modelEmotion.lowercased()] ?? .neutral
    }
}
