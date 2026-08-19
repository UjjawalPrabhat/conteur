import Foundation

/// A written-out retelling with the coverage a fair human judge would give it.
///
/// The one judgement left in the pipeline is whether the model recognises an event
/// described in different words. That cannot be unit-tested — it needs the real model on a
/// real device — but it can be *measured*, by handing it retellings whose correct answer is
/// already known and counting how often it agrees.
struct RetellingSample: Sendable, Identifiable {
    enum Shape: String, Sendable, CaseIterable {
        /// Every event, in order, with the point of the story stated.
        case faithful
        /// The opening events only, then it stops.
        case partial
        /// Every event, badly out of order.
        case scrambled
        /// Talks about the story without narrating any of it.
        case commentary
        /// Every event, but worded so that no phrase is liftable as a quote.
        case paraphrased
        /// Faithful, plus a character the story never had.
        case invented
    }

    let storyID: String
    let shape: Shape
    let spoken: String
    /// The events a fair reader would agree this retelling covers.
    let expectedBeats: Set<Int>
    let expectedStakes: Bool

    var id: String { "\(storyID)-\(shape.rawValue)" }

    var story: GuidedStory? { StoryLibrary.story(id: storyID) }

    /// Rendered at a plausible narrative speaking rate, so timings behave like real ones.
    var transcript: Transcript {
        let spacing = 60.0 / 150.0
        let words = spoken.split(whereSeparator: \.isWhitespace).enumerated().map { index, word in
            let start = Double(index) * spacing
            return SpokenWord(text: String(word), start: start, end: start + spacing * 0.6)
        }
        return Transcript(words: words)
    }
}
