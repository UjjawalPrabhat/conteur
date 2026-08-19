import Foundation

/// Rules that need the story the retelling came from.
///
/// Every one of these was either impossible or guesswork when structure had to be inferred
/// from the retelling alone. They are also almost entirely arithmetic — the story supplies
/// the answers, so nothing here is a judgement about narrative quality.

// MARK: - Structure

/// Events the story turned on that never got told.
struct OmittedEventRule: DiagnosticRule {
    let dimension = Dimension.structure

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        !input.comparison.covered.isEmpty
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        input.comparison.omittedLoadBearing.map { beat in
            Finding(
                dimension: dimension,
                subject: "omitted-\(beat.id)",
                observation: "the retelling left out \(beat.summary.firstClause)",
                magnitude: 1,
                weight: beat.isClimax ? 0.4 : 0.2,
                evidence: [.missing(beat.summary)]
            )
        }
    }
}

// MARK: - Coherence

/// A character the story could not do without, never mentioned.
struct OmittedCharacterRule: DiagnosticRule {
    let dimension = Dimension.coherence

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.timeline.delivery.wordCount >= 30
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        input.comparison.omittedCentralCast.map { entity in
            Finding(
                dimension: dimension,
                subject: "missing-\(entity.name)",
                observation: "\(entity.name) never came up, and the story does not work without them",
                magnitude: 1,
                weight: 0.3,
                evidence: [.missing(entity.name)]
            )
        }
    }
}

/// Events told in an order the story did not have.
struct SequenceAccuracyRule: DiagnosticRule {
    /// Below this a listener is reassembling the story rather than being told it.
    private static let tolerated = 0.85

    let dimension = Dimension.coherence

    /// Order needs placed events. A beat known to be covered but not located says nothing
    /// about sequence.
    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.comparison.located.count >= 3
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let accuracy = input.comparison.orderAccuracy
        guard accuracy < Self.tolerated else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "order",
                observation: "events came out in a different order from the story's",
                magnitude: 1 - accuracy,
                weight: 0.3,
                evidence: input.comparison.located.prefix(3).map {
                    Evidence(at: $0.at, quote: $0.quote, measure: nil)
                }
            )
        ]
    }
}

/// An effect told without its cause. The story authored the link, so this needs no
/// judgement about whether the retelling felt connected.
struct UncausedEventRule: DiagnosticRule {
    let dimension = Dimension.coherence

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.comparison.covered.count >= 2
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        input.comparison.uncausedEvents.map { told, cause in
            Finding(
                dimension: dimension,
                subject: "uncaused-\(told.id)",
                observation: "\(told.summary.firstClause) arrived without \(cause.summary.firstClause), which is what caused it",
                magnitude: 1,
                weight: 0.25,
                evidence: [.missing(cause.summary)]
            )
        }
    }
}

// MARK: - Relevance

/// Whether the retelling ran to the length recalling a story this long should.
///
/// Both directions are faults: skeletal means the story was reduced to a summary, padded
/// means time went somewhere the story did not need.
struct CompressionRule: DiagnosticRule {
    let dimension = Dimension.relevance

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.timeline.delivery.wordCount >= 30
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let comparison = input.comparison
        let expected = comparison.story.expectedRetellingWords
        let spoken = input.timeline.delivery.wordCount

        if comparison.isSkeletal {
            return [
                Finding(
                    dimension: dimension,
                    subject: "skeletal",
                    observation: "\(spoken) words for a story that usually takes \(expected.lowerBound) to \(expected.upperBound) to retell — it came out as a summary rather than a story",
                    magnitude: 1 - comparison.compression,
                    weight: 0.3,
                    evidence: [.missing("\(spoken) words against \(expected.lowerBound)–\(expected.upperBound)")]
                )
            ]
        }
        if comparison.isPadded {
            return [
                Finding(
                    dimension: dimension,
                    subject: "padded",
                    observation: "\(spoken) words for a story that usually takes \(expected.lowerBound) to \(expected.upperBound) to retell",
                    magnitude: comparison.compression,
                    weight: 0.25,
                    evidence: [.missing("\(spoken) words against \(expected.lowerBound)–\(expected.upperBound)")]
                )
            ]
        }
        return []
    }
}

// MARK: - Engagement

/// Whether they got across why the story mattered — Labov's evaluation, checked against
/// the stakes the author wrote down rather than against whether anything evaluative
/// happened to be said.
struct StakesRule: DiagnosticRule {
    let dimension = Dimension.engagement

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        !input.comparison.covered.isEmpty
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        guard !input.comparison.conveyedStakes else { return [] }

        return [
            Finding(
                dimension: dimension,
                subject: "stakes",
                observation: "you told what happened, but not \(input.comparison.story.stakes)",
                magnitude: 1,
                weight: 0.4,
                evidence: [
                    .missing(input.comparison.story.stakes)
                ]
            )
        ]
    }
}

// MARK: - Fidelity

/// People the story never had.
///
/// The failure this exists for is the one that made the whole ground-truth approach worth
/// trying: a retelling — or an analysis of one — populated with characters out of nowhere.
struct InventionRule: DiagnosticRule {
    let dimension = Dimension.fidelity

    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.timeline.delivery.wordCount >= 30
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let invented = input.comparison.inventedNames
        guard !invented.isEmpty else { return [] }

        let names = invented.map(\.name)
        return [
            Finding(
                dimension: dimension,
                subject: "invented-names",
                observation: "you brought in \(names.formattedList), who \(names.count == 1 ? "is" : "are") not in the story",
                magnitude: Double(invented.count),
                weight: 0.35,
                evidence: invented.map { .at($0.at, quote: $0.name) }
            )
        ]
    }
}

/// How much of the story survived at all.
struct CoverageRule: DiagnosticRule {
    /// Adults recall well under everything on one reading, so this is deliberately not
    /// demanding — it flags a retelling that lost most of the story, not an imperfect one.
    private static let tolerated = 0.5

    let dimension = Dimension.fidelity

    /// Needs at least one recognised event. With none, "they told none of it" cannot be
    /// told apart from "none of it was recognised", and reporting a share would claim
    /// knowledge the comparison does not have.
    func canEvaluate(in input: DiagnosticInput) -> Bool {
        input.timeline.delivery.wordCount >= 30 && !input.comparison.covered.isEmpty
    }

    func findings(in input: DiagnosticInput) -> [Finding] {
        let share = input.comparison.coverageShare
        guard share < Self.tolerated else { return [] }

        let total = input.comparison.story.loadBearingBeats.count
        let told = Int(share * Double(total))
        return [
            Finding(
                dimension: dimension,
                subject: "coverage",
                observation: "\(told) of the story's \(total) events came through",
                magnitude: 1 - share,
                weight: 0.3,
                evidence: input.comparison.omittedLoadBearing.prefix(2).map {
                    .missing($0.summary)
                }
            )
        ]
    }
}

private extension [String] {
    var formattedList: String {
        guard count > 1, let last = self.last else { return first ?? "" }
        return dropLast().joined(separator: ", ") + " and " + last
    }
}

private extension String {
    /// Beat summaries are written as full clauses; feedback reads better with just the
    /// first one.
    var firstClause: String {
        split(separator: ",").first.map(String.init) ?? self
    }
}
