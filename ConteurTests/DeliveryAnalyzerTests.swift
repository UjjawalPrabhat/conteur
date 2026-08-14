import Foundation
import Testing

@testable import Conteur

struct DeliveryAnalyzerTests {
    private let analyzer = DeliveryAnalyzer()

    @Test func emptyTranscriptProducesNoSignals() {
        #expect(analyzer.analyze(.empty) == .empty)
    }

    @Test func paceIsWordsOverElapsedTime() {
        // 60 back-to-back words of half a second each spans exactly 30 seconds.
        let transcript = transcript(
            spacing: 0.5,
            wordDuration: 0.5,
            words: Array(repeating: "word", count: 60)
        )
        let signals = analyzer.analyze(transcript)

        #expect(signals.wordCount == 60)
        #expect(signals.duration == 30)
        #expect(signals.wordsPerMinute == 120)
    }

    @Test func shortGapsAreOrdinaryRhythmRatherThanPauses() {
        let signals = analyzer.analyze(transcript(spacing: 0.2, words: ["one", "two", "three"]))

        #expect(signals.pauses(of: .syntactic).count == 2)
        #expect(signals.pauses(of: .hesitation).isEmpty)
    }

    @Test func longGapMidClauseReadsAsHesitation() {
        let signals = analyzer.analyze(
            Transcript(words: [
                SpokenWord(text: "and", start: 0, end: 0.4),
                SpokenWord(text: "then", start: 2.4, end: 2.8),
            ])
        )

        #expect(signals.pauses(of: .hesitation).count == 1)
        #expect(signals.pauses(of: .dramatic).isEmpty)
    }

    @Test func sameGapAfterClauseEndReadsAsDeliberate() {
        let signals = analyzer.analyze(
            Transcript(words: [
                SpokenWord(text: "gone.", start: 0, end: 0.4),
                SpokenWord(text: "Then", start: 2.4, end: 2.8),
            ])
        )

        #expect(signals.pauses(of: .dramatic).count == 1)
        #expect(signals.pauses(of: .hesitation).isEmpty)
    }

    @Test func silenceBeyondThreeSecondsIsAStall() {
        let signals = analyzer.analyze(
            Transcript(words: [
                SpokenWord(text: "so", start: 0, end: 0.4),
                SpokenWord(text: "anyway", start: 4.0, end: 4.6),
            ])
        )

        #expect(signals.pauses(of: .stall).count == 1)
    }

    @Test func filledPausesAreCountedAsARateNotATotal() {
        let signals = analyzer.analyze(
            transcript(spacing: 0.2, words: ["um", "he", "uh", "left"])
        )

        #expect(signals.filledPauses.map(\.token) == ["um", "uh"])
        #expect(signals.filledPauseRate == 0.5)
    }

    @Test func genuineInterjectionsAreNotTreatedAsFiller() {
        let signals = analyzer.analyze(transcript(spacing: 0.2, words: ["ah", "er", "so"]))

        #expect(signals.filledPauses.isEmpty)
    }

    @Test func repeatedPhraseIsARestart() {
        let signals = analyzer.analyze(
            transcript(spacing: 0.2, words: ["he", "went", "to", "he", "went", "to", "the", "house"])
        )

        #expect(signals.restarts.count == 1)
        #expect(signals.restarts.first?.phrase == "he went to")
    }

    @Test func punctuationAndCaseDoNotHideARestart() {
        let signals = analyzer.analyze(
            transcript(spacing: 0.2, words: ["She", "left,", "she", "left", "quietly"])
        )

        #expect(signals.restarts.count == 1)
    }

    @Test func distinctPhrasesAreNotRestarts() {
        let signals = analyzer.analyze(
            transcript(spacing: 0.2, words: ["he", "went", "she", "stayed"])
        )

        #expect(signals.restarts.isEmpty)
    }

    /// Builds evenly spaced words so a test only has to state the words it cares about.
    /// Words occupy half their slot by default, leaving a gap between each pair.
    private func transcript(
        spacing: TimeInterval,
        wordDuration: TimeInterval? = nil,
        words: [String]
    ) -> Transcript {
        let spoken = words.enumerated().map { index, text in
            let start = Double(index) * spacing
            return SpokenWord(text: text, start: start, end: start + (wordDuration ?? spacing / 2))
        }
        return Transcript(words: spoken)
    }
}
