import Foundation

/// Rules that need only the recording. Unchanged by the story being known, because how
/// somebody speaks does not depend on what they are speaking about.

/// A rate rather than a count, so a long retelling isn't penalised for being long.
struct FilledPauseRule: DiagnosticRule {
    private static let tolerated = 0.04

    let dimension = Dimension.delivery

    func canEvaluate(in input: DiagnosticInput) -> Bool { input.timeline.delivery.wordCount > 50 }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let signals = input.timeline.delivery
        let rate = signals.filledPauseRate
        guard rate > Self.tolerated else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "fillers",
                observation: "\(signals.filledPauses.count) filled pauses across \(signals.wordCount) words",
                magnitude: rate,
                weight: 0.2,
                evidence: signals.filledPauses.prefix(3).map {
                    .at($0.at, quote: $0.token, measure: rate.percentLabel)
                }
            )
        ]
    }
}

struct StallRule: DiagnosticRule {
    private static let tolerated = 2

    let dimension = Dimension.delivery

    func canEvaluate(in input: DiagnosticInput) -> Bool { input.timeline.delivery.wordCount >= 30 }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let stalls = input.timeline.delivery.pauses(of: .stall)
        guard stalls.count > Self.tolerated else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "stalls",
                observation: "\(stalls.count) silences ran long enough for a listener to wonder whether you were coming back",
                magnitude: Double(stalls.count),
                weight: 0.25,
                evidence: stalls.prefix(3).map {
                    .at($0.start, measure: $0.duration.secondsLabel)
                }
            )
        ]
    }
}

/// Restarting a phrase is normal in speech; doing it often enough to notice is not.
struct RestartRule: DiagnosticRule {
    private static let tolerated = 3

    let dimension = Dimension.coherence

    func canEvaluate(in input: DiagnosticInput) -> Bool { input.timeline.delivery.wordCount >= 30 }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let restarts = input.timeline.delivery.restarts
        guard restarts.count > Self.tolerated else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "restarts",
                observation: "\(restarts.count) sentences were restarted mid-phrase",
                magnitude: Double(restarts.count),
                weight: 0.2,
                evidence: restarts.prefix(3).map {
                    .at($0.at, quote: $0.phrase)
                }
            )
        ]
    }
}

/// A story told at one pitch. Measured as coefficient of variation so it compares a
/// speaker against themselves rather than against a register.
struct MonotoneRule: DiagnosticRule {
    private static let minimumVariation: Float = 0.12

    let dimension = Dimension.engagement

    /// Pitch needs voiced audio, not beats — a short retelling can still be monotone.
    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.timeline.prosody.contains { $0.pitch != nil }
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let variation = input.timeline.pitchVariation
        guard variation > 0, variation < Self.minimumVariation else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "pitch",
                observation: "the pitch of your voice barely moved across the whole retelling",
                // How far short of moving enough, so a voice that moved more reads better.
                magnitude: Double(Self.minimumVariation - variation),
                weight: 0.3,
                evidence: [
                    Evidence(at: nil, quote: nil, measure: Double(variation).percentLabel)
                ]
            )
        ]
    }
}

/// A face that stays still through the moment the story turns on.
///
/// The turning point is authored, and the comparison says when the reteller reached it, so
/// this now checks the exact moment rather than a moment the model nominated.
struct FlatClimaxRule: DiagnosticRule {
    private static let stillness: Float = 0.02

    let dimension = Dimension.engagement

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.comparison.climaxCoverage != nil && !input.timeline.expressivity.isEmpty
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        guard
            let climax = input.comparison.climaxCoverage,
            let variation = input.timeline.expressivity(at: climax.at),
            variation < Self.stillness
        else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "climax-expression",
                observation: "your face stayed still through the turning point at \(climax.at.timestampLabel)",
                magnitude: Double(Self.stillness - variation),
                weight: 0.25,
                evidence: [.at(climax.at, quote: climax.quote)]
            )
        ]
    }
}

/// Speeding up through the moment that most deserves room.
struct RushedClimaxRule: DiagnosticRule {
    /// A fifth faster than the speaker's own average is enough to hear.
    private static let excess = 1.2

    let dimension = Dimension.delivery

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.comparison.climaxCoverage != nil && input.timeline.delivery.wordsPerMinute > 0
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        guard let climax = input.comparison.climaxCoverage else { return [] }

        let average = input.timeline.delivery.wordsPerMinute
        let span = input.comparison.span(of: climax, endingBy: input.timeline.duration)
        let local = input.timeline.wordsPerMinute(in: span)
        guard average > 0, local > average * Self.excess else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "climax-pace",
                observation: "you sped up to \(Int(local)) words a minute through the turning point, against \(Int(average)) across the rest",
                magnitude: local / average,
                weight: 0.25,
                evidence: [.at(climax.at, quote: climax.quote, measure: "\(Int(local)) wpm")]
            )
        ]
    }
}
