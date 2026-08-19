import Foundation

/// Something named and then abandoned. Computed as a set difference over the beats,
/// which is why it can be stated precisely rather than described vaguely.
struct DroppedThreadRule: DiagnosticRule {
    let dimension = Dimension.coherence

    /// A thread can only be dropped if there was somewhere later to pick it up,
    /// and only if the introduction was substantial enough to count as a thread.
    private static let minimumBeatCount = 3

    func canEvaluate(in input: DiagnosticInput) -> Bool { input.narrative.beats.count >= Self.minimumBeatCount }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let beats = input.narrative.beats
        guard beats.count >= Self.minimumBeatCount else { return [] }

        // Count how many beats mention each entity, across introduced and referenced.
        var mentionCounts: [String: Int] = [:]
        for beat in beats {
            for entity in beat.entitiesIntroduced {
                mentionCounts[entity, default: 0] += 1
            }
            for entity in beat.entitiesReferenced {
                mentionCounts[entity, default: 0] += 1
            }
        }

        var introductions: [String: Beat] = [:]
        for beat in beats {
            for entity in beat.entitiesIntroduced where introductions[entity] == nil {
                introductions[entity] = beat
            }
        }

        let everReferenced = Set(beats.flatMap(\.entitiesReferenced))

        return introductions
            .filter { entity, beat in
                // The entity must appear at least twice across all beats — a single
                // mention is colour, not a thread.
                guard (mentionCounts[entity] ?? 0) >= 2 else { return false }

                // The introduction must not be the final beat — trailing off is not
                // abandonment.
                guard beat.end < beats.last?.end ?? 0 else { return false }

                // The entity must never have been referenced in a later beat.
                return !everReferenced.contains(entity)
            }
            .sorted { $0.value.start < $1.value.start }
            .map { entity, beat in
                Finding(
                    dimension: dimension,
                    subject: entity,
                    observation: "\(entity) was introduced at \(beat.start.timestampLabel) and never came up again",
                    magnitude: 1,
                    weight: 0.3,
                    evidence: [Evidence(at: beat.start, quote: beat.summary, measure: nil)]
                )
            }
    }
}

/// Beats joined only by sequence rather than cause — the "and then, and then" retelling.
struct CausalDensityRule: DiagnosticRule {
    /// Below this share of beats carrying a causal link, a listener is assembling the
    /// story themselves rather than being told it.
    private static let minimumShare = 0.4

    let dimension = Dimension.coherence

    func canEvaluate(in input: DiagnosticInput) -> Bool { input.narrative.beats.count >= 3 }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let beats = input.narrative.beats
        guard beats.count >= 3 else { return [] }

        let causal = beats.count { $0.connectsCausally }
        let share = Double(causal) / Double(beats.count)
        guard share < Self.minimumShare else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "causal-links",
                observation: "only \(causal) of \(beats.count) stretches connected one event to the next by cause",
                magnitude: 1 - share,
                weight: 0.3,
                evidence: [
                    Evidence(
                        at: beats[0].start,
                        quote: nil,
                        measure: share.formatted(.percent.precision(.fractionLength(0)))
                    )
                ]
            )
        ]
    }
}

struct SequencingRule: DiagnosticRule {
    let dimension = Dimension.coherence

    func canEvaluate(in input: DiagnosticInput) -> Bool { !input.narrative.beats.isEmpty }

    func findings(in input: DiagnosticInput) -> [Finding] {
        guard !input.narrative.beats.isEmpty, !input.narrative.arc.sequencingIsFollowable else {
            return []
        }
        return [
            Finding(
                dimension: dimension,
                subject: "sequencing",
                observation: "the order of events was hard to follow",
                magnitude: 1,
                weight: 0.35,
                evidence: [Evidence(at: 0, quote: nil, measure: nil)]
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
                    Evidence(at: $0.at, quote: $0.phrase, measure: nil)
                }
            )
        ]
    }
}
