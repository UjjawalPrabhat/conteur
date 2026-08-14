import Foundation

/// A rate rather than a count, so a long retelling isn't penalised for being long.
struct FilledPauseRule: DiagnosticRule {
    private static let tolerated = 0.04

    let dimension = Dimension.delivery

    func findings(in input: DiagnosticInput) -> [Finding] {
        let signals = input.timeline.delivery
        let rate = signals.filledPauseRate
        guard rate > Self.tolerated, signals.wordCount > 50 else { return [] }

        return [
            Finding(
                dimension: dimension,
                observation: "\(signals.filledPauses.count) filled pauses across \(signals.wordCount) words",
                weight: 0.2,
                evidence: signals.filledPauses.prefix(3).map {
                    Evidence(at: $0.at, quote: $0.token, measure: rate.percentLabel)
                }
            )
        ]
    }
}

struct StallRule: DiagnosticRule {
    private static let tolerated = 2

    let dimension = Dimension.delivery

    func findings(in input: DiagnosticInput) -> [Finding] {
        let stalls = input.timeline.delivery.pauses(of: .stall)
        guard stalls.count > Self.tolerated else { return [] }

        return [
            Finding(
                dimension: dimension,
                observation: "\(stalls.count) silences ran long enough for a listener to wonder whether you were coming back",
                weight: 0.25,
                evidence: stalls.prefix(3).map {
                    Evidence(at: $0.start, quote: nil, measure: $0.duration.secondsLabel)
                }
            )
        ]
    }
}

/// Speeding up through the moment that most deserves room.
struct RushedClimaxRule: DiagnosticRule {
    /// A fifth faster than the speaker's own average is enough to hear.
    private static let excess = 1.2

    let dimension = Dimension.delivery

    func findings(in input: DiagnosticInput) -> [Finding] {
        guard
            let index = input.narrative.arc.climaxBeat,
            input.narrative.beats.indices.contains(index)
        else { return [] }

        let climax = input.narrative.beats[index]
        let average = input.timeline.delivery.wordsPerMinute
        guard average > 0 else { return [] }

        let local = input.timeline.wordsPerMinute(in: climax.start..<climax.end)
        guard local > average * Self.excess else { return [] }

        return [
            Finding(
                dimension: dimension,
                observation: "you sped up to \(Int(local)) words a minute through the turning point, against \(Int(average)) across the rest",
                weight: 0.25,
                evidence: [
                    Evidence(
                        at: climax.start,
                        quote: climax.summary,
                        measure: "\(Int(local)) wpm"
                    )
                ]
            )
        ]
    }
}
