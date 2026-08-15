import Foundation

/// Events recounted without ever saying what was at stake — accurate but inert.
struct StakesGapRule: DiagnosticRule {
    let dimension = Dimension.engagement

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.narrative.beats.count { $0.kind == .corePlot } >= 2
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let beats = input.narrative.beats
        let core = beats.filter { $0.kind == .corePlot }
        guard core.count >= 2, !beats.contains(where: \.statesStakes) else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "stakes",
                observation: "the retelling never said what was at stake or why any of it mattered",
                magnitude: 1,
                weight: 0.4,
                evidence: core.prefix(2).map {
                    Evidence(at: $0.start, quote: $0.summary, measure: nil)
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
                    Evidence(at: 0, quote: nil, measure: Double(variation).percentLabel)
                ]
            )
        ]
    }
}

/// A face that stays still through the moment the story turns on.
struct FlatClimaxRule: DiagnosticRule {
    private static let stillness: Float = 0.02

    let dimension = Dimension.engagement

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.narrative.arc.climaxBeat != nil && !input.timeline.expressivity.isEmpty
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        guard
            let index = input.narrative.arc.climaxBeat,
            input.narrative.beats.indices.contains(index)
        else { return [] }

        let climax = input.narrative.beats[index]
        guard
            let variation = input.timeline.expressivity(at: climax.start),
            variation < Self.stillness
        else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "climax-expression",
                observation: "your face stayed still through the turning point at \(climax.start.timestampLabel)",
                magnitude: Double(Self.stillness - variation),
                weight: 0.25,
                evidence: [
                    Evidence(
                        at: climax.start,
                        quote: climax.summary,
                        measure: nil
                    )
                ]
            )
        ]
    }
}
