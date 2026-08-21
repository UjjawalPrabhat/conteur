import Foundation

struct EmotionalEngine: Sendable {
    private static let minimumConfidence: Double = 0.6
    private let classifier: CoreMLEmotionClassifier
    private let featureExtractor: EmotionFeatureExtractor

    init(
        classifier: CoreMLEmotionClassifier = CoreMLEmotionClassifier(),
        featureExtractor: EmotionFeatureExtractor = EmotionFeatureExtractor()
    ) {
        self.classifier = classifier
        self.featureExtractor = featureExtractor
    }

    func evaluate(beats: [Beat], expressions: [ExpressionSample]) -> [EmotionMatch] {
        beats
            .emotionalBeats()
            .compactMap { beat in
                guard let expected = expectedEmotion(for: beat) else { return nil }
                let actualReading = actualEmotion(during: beat.start..<beat.end, from: expressions)
                guard let actual = actualReading else { return nil }
                return compare(expected: expected, actual: actual, beat: beat)
            }
    }

    private func expectedEmotion(for beat: Beat) -> DetectedEmotion? {
        guard let raw = beat.expectedEmotion, !raw.isEmpty else { return nil }
        return DetectedEmotion(rawValue: raw.lowercased())
    }

    private func actualEmotion(during range: Range<TimeInterval>, from expressions: [ExpressionSample]) -> DetectedEmotion? {
        let windows = expressions.filter { range.contains($0.at) }
        guard !windows.isEmpty else { return nil }

        let dominant = windows
            .reduce(into: [DetectedEmotion: Double]()) { counts, sample in
                let probabilities: [String: Double]?
                if let existing = sample.probabilities, !existing.isEmpty {
                    probabilities = existing
                } else if let features = featureExtractor.features(from: sample), let mlProbabilities = classifier.probabilities(from: features) {
                    probabilities = mlProbabilities
                } else {
                    probabilities = nil
                }

                guard let emotionProbabilities = probabilities else { return }
                if let emotion = EmotionClassifier().reading(from: emotionProbabilities) {
                    counts[emotion, default: 0] += 1
                }
            }
            .max { $0.value < $1.value }
        guard let dominantEmotion = dominant?.key else { return nil }

        let total = Double(windows.count)
        let share = (dominant?.value ?? 0) / total
        guard share >= 0.5 else { return nil }

        return dominantEmotion
    }

    private func compare(expected: DetectedEmotion, actual: DetectedEmotion, beat: Beat) -> EmotionMatch {
        let result: MatchResult
        let description: String

        if expected == actual {
            result = .matched
            description = "emotion matched expected tone"
        } else {
            result = .mismatched
            description = "expected \(expected.rawValue), delivered \(actual.rawValue)"
        }

        return EmotionMatch(
            beatStart: beat.start,
            expected: expected,
            actual: actual,
            result: result,
            description: description
        )
    }

    func produceEvents(from matches: [EmotionMatch], session: Int) -> [BookEvent] {
        matches.map { match in
            BookEvent(
                sessionNumber: session,
                timestamp: match.beatStart,
                kind: match.result.eventKind,
                subject: match.expected.rawValue,
                detailText: match.description,
                evidenceStart: match.beatStart
            )
        }
    }
}
