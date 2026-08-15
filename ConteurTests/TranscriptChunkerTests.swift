import Foundation
import Testing

@testable import Conteur

struct TranscriptChunkerTests {
    private let chunker = TranscriptChunker()

    /// The model fills whatever summary it is asked for. Handed two words it invents a
    /// scene, so it is never handed two words.
    @Test func aHandfulOfWordsIsNotWorthLabelling() {
        #expect(chunker.chunks(of: transcript(words: 2)).isEmpty)
        #expect(chunker.chunks(of: transcript(words: 11)).isEmpty)
    }

    @Test func enoughToBeAStretchOfStoryIsLabelled() {
        #expect(chunker.chunks(of: transcript(words: 30)).count == 1)
    }

    @Test func aLongRetellingIsSplitIntoChunks() {
        // 300 words at 0.4s apart is two minutes, past the 90s hard break.
        let chunks = chunker.chunks(of: transcript(words: 300, spacing: 0.4))

        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.end - $0.start <= 91 })
    }

    /// A trailing fragment joins the chunk before it rather than being labelled alone.
    @Test func aShortTailIsFoldedIntoThePreviousChunk() {
        let chunks = chunker.chunks(of: transcript(words: 230, spacing: 0.4))

        #expect(chunks.allSatisfy { $0.words.count >= TranscriptChunker.minimumWords })
    }

    @Test func chunksCoverEveryWordExactlyOnce() {
        let source = transcript(words: 400, spacing: 0.4)
        let chunks = chunker.chunks(of: source)

        #expect(chunks.flatMap(\.words) == source.words)
    }

    private func transcript(words: Int, spacing: TimeInterval = 0.4) -> Transcript {
        Transcript(
            words: (0..<words).map { index in
                let start = Double(index) * spacing
                return SpokenWord(text: "word\(index)", start: start, end: start + spacing / 2)
            }
        )
    }
}
