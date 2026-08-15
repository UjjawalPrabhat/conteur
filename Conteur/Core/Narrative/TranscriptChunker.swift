import Foundation

struct TranscriptChunk: Sendable, Hashable {
    let words: [SpokenWord]

    var start: TimeInterval { words.first?.start ?? 0 }
    var end: TimeInterval { words.last?.end ?? 0 }
    var text: String { words.map(\.text).joined(separator: " ") }
}

/// Splits a retelling into stretches small enough to fit the on-device model's
/// session budget, breaking at pauses so a chunk rarely cuts mid-thought.
struct TranscriptChunker: Sendable {
    /// Short enough that a chunk plus instructions plus output stays inside the
    /// 4,096-token session budget, long enough to contain a whole beat.
    ///
    /// Kept deliberately short: several rules need more than one beat to say anything,
    /// so minute-long chunks left any retelling under two minutes unjudgeable on
    /// coherence and engagement. Thirty seconds is still only ~100 tokens.
    private static let preferredDuration: TimeInterval = 30
    private static let maximumDuration: TimeInterval = 45

    /// Any gap this long is a reasonable seam; below it, splitting would cut a phrase.
    private static let seamGap: TimeInterval = 0.5

    /// Fewer words than this is not a stretch of story. Handed one, the model will
    /// invent a scene to fill the summary it has been asked for, so it is never asked.
    static let minimumWords = 12

    func chunks(of transcript: Transcript) -> [TranscriptChunk] {
        var chunks: [TranscriptChunk] = []
        var current: [SpokenWord] = []

        for (index, word) in transcript.words.enumerated() {
            current.append(word)
            guard let first = current.first else { continue }

            let elapsed = word.end - first.start
            let gapFollows = transcript.words.indexAfter(index).map {
                $0.start - word.end >= Self.seamGap
            } ?? false

            let readyToBreak = elapsed >= Self.preferredDuration && gapFollows
            let mustBreak = elapsed >= Self.maximumDuration

            if readyToBreak || mustBreak {
                chunks.append(TranscriptChunk(words: current))
                current = []
            }
        }

        if !current.isEmpty {
            // A trailing fragment joins the chunk before it rather than being labelled
            // on its own.
            if current.count < Self.minimumWords, let previous = chunks.popLast() {
                chunks.append(TranscriptChunk(words: previous.words + current))
            } else {
                chunks.append(TranscriptChunk(words: current))
            }
        }

        // Too little was said for any of it to be worth labelling.
        guard chunks.contains(where: { $0.words.count >= Self.minimumWords }) else { return [] }
        return chunks
    }
}

private extension [SpokenWord] {
    func indexAfter(_ index: Int) -> SpokenWord? {
        let next = index + 1
        return indices.contains(next) ? self[next] : nil
    }
}
