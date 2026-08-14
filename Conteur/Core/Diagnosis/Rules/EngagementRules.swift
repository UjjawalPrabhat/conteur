import Foundation

/// Events recounted without ever saying what was at stake — accurate but inert.
struct StakesGapRule: DiagnosticRule {
    let dimension = Dimension.engagement

    func findings(in input: DiagnosticInput) -> [Finding] {
        let beats = input.narrative.beats
        let core = beats.filter { $0.kind == .corePlot }
        guard core.count >= 2, !beats.contains(where: \.statesStakes) else { return [] }

        return [
            Finding(
                dimension: dimension,
                observation: "the retelling never said what was at stake or why any of it mattered",
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

    func findings(in input: DiagnosticInput) -> [Finding] {
        let variation = input.timeline.pitchVariation
        guard variation > 0, variation < Self.minimumVariation else { return [] }

        return [
            Finding(
                dimension: dimension,
                observation: "the pitch of your voice barely moved across the whole retelling",
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
                observation: "your face stayed still through the turning point at \(climax.start.timestampLabel)",
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
