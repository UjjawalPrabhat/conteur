import Foundation

/// Derives delivery signals from word timings alone. Pure and deterministic, so the
/// same recording always produces the same numbers.
struct DeliveryAnalyzer: Sendable {
    private enum Threshold {
        /// Below this, a gap is the ordinary rhythm of speech rather than a pause.
        static let syntactic: TimeInterval = 0.5
        /// Above this, a gap is long enough to read as deliberate — but only at a
        /// clause boundary; mid-clause it reads as searching for the next word.
        static let deliberate: TimeInterval = 1.5
        /// Above this, the listener has started to wonder whether you're coming back.
        static let stall: TimeInterval = 3.0
    }

    /// Excludes "er" and "ah", which are common enough as genuine interjections
    /// that counting them as filler produces more noise than signal.
    private static let filledPauseTokens: Set<String> = [
        "um", "uh", "uhm", "erm", "hmm", "mm", "mhm",
    ]

    private static let restartPhraseLengths = 2...4

    func analyze(_ transcript: Transcript) -> DeliverySignals {
        let words = transcript.words
        guard !words.isEmpty else { return .empty }

        let duration = transcript.duration
        return DeliverySignals(
            wordCount: words.count,
            duration: duration,
            wordsPerMinute: duration > 0 ? Double(words.count) / duration * 60 : 0,
            pauses: pauses(in: words),
            filledPauses: filledPauses(in: words),
            restarts: restarts(in: words)
        )
    }

    private func pauses(in words: [SpokenWord]) -> [Pause] {
        zip(words, words.dropFirst()).compactMap { current, next in
            let gap = next.start - current.end
            guard gap > 0 else { return nil }
            return Pause(kind: kind(ofGap: gap, after: current), start: current.end, duration: gap)
        }
    }

    private func kind(ofGap gap: TimeInterval, after word: SpokenWord) -> PauseKind {
        switch gap {
        case ..<Threshold.syntactic: .syntactic
        case Threshold.stall...: .stall
        case Threshold.deliberate...: word.endsClause ? .dramatic : .hesitation
        default: .hesitation
        }
    }

    private func filledPauses(in words: [SpokenWord]) -> [FilledPause] {
        words.compactMap { word in
            let token = word.normalized
            guard Self.filledPauseTokens.contains(token) else { return nil }
            return FilledPause(token: token, at: word.start)
        }
    }

    private func restarts(in words: [SpokenWord]) -> [Restart] {
        var found: [Restart] = []
        var index = 0

        while index < words.count {
            guard let length = Self.restartPhraseLengths.first(where: { repeats(in: words, at: index, length: $0) }) else {
                index += 1
                continue
            }
            let phrase = words[index..<index + length].map(\.text).joined(separator: " ")
            found.append(Restart(phrase: phrase, at: words[index].start))
            index += length * 2
        }

        return found
    }

    private func repeats(in words: [SpokenWord], at index: Int, length: Int) -> Bool {
        guard index + length * 2 <= words.count else { return false }
        let first = words[index..<index + length].map(\.normalized)
        let second = words[index + length..<index + length * 2].map(\.normalized)
        return first == second
    }
}
