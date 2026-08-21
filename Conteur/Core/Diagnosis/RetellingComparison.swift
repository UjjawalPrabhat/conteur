import Foundation

enum ChallengeVerdict: String, Sendable, Hashable {
    case met
    case closer
    case notYet

    var label: String {
        switch self {
        case .met: "Met"
        case .closer: "Closer"
        case .notYet: "Not this time"
        }
    }

    var symbol: String {
        switch self {
        case .met: "checkmark.circle.fill"
        case .closer: "arrow.up.right.circle.fill"
        case .notYet: "circle.dashed"
        }
    }
}

/// What the second telling changed.
struct RetellingProgress: Sendable, Hashable {
    let challenge: String
    let focus: Dimension
    let verdict: ChallengeVerdict
    /// Findings from the first telling that did not come back.
    let resolved: [Finding]
    /// The same problems, still there.
    let persisted: [Finding]
    /// Problems that were not there the first time.
    let introduced: [Finding]
    let before: Band
    let after: Band
}

/// Per-dimension delta between two attempts.
struct DimensionDelta: Sendable, Identifiable, Hashable {
    let id: UUID
    let dimension: Dimension
    let before: Band
    let after: Band
    let beforeScore: Double
    let afterScore: Double
    let resolved: [Finding]
    let persisted: [Finding]
    let introduced: [Finding]
    let improvement: Double  // afterScore - beforeScore, can be negative
}

struct AttemptComparison: Sendable, Hashable {
    let attemptNumber: Int
    let mode: ChallengeMode
    let challenge: String
    let focusDimension: Dimension?
    let deltas: [DimensionDelta]
    let overallVerdict: ChallengeVerdict
    let primaryImprovement: DimensionDelta?
    let newProblemAreas: [DimensionDelta]
    let otherDeltas: [DimensionDelta]
}

struct StandaloneDelta: Sendable, Hashable {
    let dimension: Dimension
    let asContinuation: Band
    let asStandalone: Band
    let difference: Double
    let standaloneOnlyFindings: [Finding]
    let continuationOnlyFindings: [Finding]
}

struct RetellingComparisonInput: Sendable {
    let first: Diagnosis
    let second: Diagnosis
    let challenge: String
    let mode: ChallengeMode
}

/// Compares two tellings on the dimension the challenge targeted.
///
/// Pure arithmetic over finding identities and magnitudes, never the model's impression
/// — so the app cannot congratulate somebody for something they did not do.
struct RetellingComparison: Sendable {
    /// A problem has to shrink by more than a rounding difference to count as progress.
    private static let meaningfulImprovement = 0.1

    func compare(
        _ first: Diagnosis,
        with second: Diagnosis,
        challenge: String
    ) -> RetellingProgress? {
        guard first.isJudgeable, second.isJudgeable else { return nil }

        // Nothing was wrong the first time, so the challenge was a stretch rather than a
        // correction. It holds if the second telling is still clean.
        guard let focus = first.focus else {
            let introduced = second.assessments.flatMap(\.findings)
            let dimension = second.focus?.dimension ?? first.strengths.first?.dimension ?? .structure
            return RetellingProgress(
                challenge: challenge,
                focus: dimension,
                verdict: introduced.isEmpty ? .met : .notYet,
                resolved: [],
                persisted: [],
                introduced: introduced,
                before: first.assessment(for: dimension)?.band ?? .insufficient,
                after: second.assessment(for: dimension)?.band ?? .insufficient
            )
        }

        let before = focus.findings
        let after = second.assessment(for: focus.dimension)?.findings ?? []
        let afterByIdentity = Dictionary(
            after.map { ($0.identity, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let beforeIdentities = Set(before.map(\.identity))

        let persisted = before.compactMap { afterByIdentity[$0.identity] }
        let resolved = before.filter { afterByIdentity[$0.identity] == nil }
        let introduced = after.filter { !beforeIdentities.contains($0.identity) }

        return RetellingProgress(
            challenge: challenge,
            focus: focus.dimension,
            verdict: verdict(before: before, persisted: persisted),
            resolved: resolved,
            persisted: persisted,
            introduced: introduced,
            before: focus.band,
            after: second.assessment(for: focus.dimension)?.band ?? .insufficient
        )
    }

    func attemptComparison(from input: RetellingComparisonInput) -> AttemptComparison {
        let primaryDelta: DimensionDelta?
        if let focus = input.first.focus?.dimension {
            primaryDelta = delta(for: focus, first: input.first, second: input.second)
        } else {
            primaryDelta = nil
        }
        let otherDeltas: [DimensionDelta] = Dimension.allCases.compactMap { dimension in
            guard dimension != input.first.focus?.dimension else { return nil }
            return delta(for: dimension, first: input.first, second: input.second)
        }
        let newProblemAreas = otherDeltas.filter { !$0.introduced.isEmpty }
        let overallImprovement = otherDeltas.reduce(0) { $0 + $1.improvement } + (primaryDelta?.improvement ?? 0)
        let verdict = computeVerdict(primaryDelta: primaryDelta, newProblems: newProblemAreas, overallImprovement: overallImprovement)

        return AttemptComparison(
            attemptNumber: 0,
            mode: input.mode,
            challenge: input.challenge,
            focusDimension: input.first.focus?.dimension,
            deltas: ([primaryDelta] + otherDeltas).compactMap { $0 },
            overallVerdict: verdict,
            primaryImprovement: primaryDelta,
            newProblemAreas: newProblemAreas,
            otherDeltas: otherDeltas
        )
    }

    func standaloneDelta(from first: Diagnosis, continuation second: Diagnosis, standalone third: Diagnosis) -> StandaloneDelta {
        let dimensions = Dimension.allCases
        let deltas = dimensions.map { dimension in
            (
                dimension,
                first.assessment(for: dimension)?.band ?? .insufficient,
                second.assessment(for: dimension)?.band ?? .insufficient,
                third.assessment(for: dimension)?.band ?? .insufficient
            )
        }

        let target = first.focus?.dimension ?? .structure
        guard let targetDelta = deltas.first(where: { $0.0 == target }) else {
            return StandaloneDelta(dimension: target, asContinuation: .insufficient, asStandalone: .insufficient, difference: 0, standaloneOnlyFindings: [], continuationOnlyFindings: [])
        }

        let continuationFindings = second.assessment(for: target)?.findings ?? []
        let standaloneFindings = third.assessment(for: target)?.findings ?? []
        let continuationIds = Set(continuationFindings.map(\.identity))

        return StandaloneDelta(
            dimension: target,
            asContinuation: targetDelta.2,
            asStandalone: targetDelta.3,
            difference: Band.score(band: targetDelta.3) - Band.score(band: targetDelta.2),
            standaloneOnlyFindings: standaloneFindings.filter { !continuationIds.contains($0.identity) },
            continuationOnlyFindings: continuationFindings.filter { !Set(standaloneFindings.map(\.identity)).contains($0.identity) }
        )
    }

    func nextChallenge(after comparison: AttemptComparison, mode: ChallengeMode) -> String? {
        if let primaryDelta = comparison.primaryImprovement, primaryDelta.improvement >= 0.3, primaryDelta.resolved.count >= primaryDelta.persisted.count {
            let nextWeakest = comparison.otherDeltas
                .sorted { $0.afterScore < $1.afterScore }
                .first

            guard let next = nextWeakest else { return nil }
            return challengeText(for: next.dimension, mode: mode, basedOn: next.persisted)
        }

        return comparison.challenge
    }

    /// Gone is met. Still there but smaller is progress, and saying otherwise would tell
    /// somebody who improved that they failed. Still there and unchanged is not yet.
    private func verdict(before: [Finding], persisted: [Finding]) -> ChallengeVerdict {
        guard !persisted.isEmpty else { return .met }

        let was = before
            .filter { finding in persisted.contains { $0.identity == finding.identity } }
            .reduce(0) { $0 + $1.magnitude }
        let now = persisted.reduce(0) { $0 + $1.magnitude }

        guard was > 0 else { return .notYet }
        return (was - now) / was >= Self.meaningfulImprovement ? .closer : .notYet
    }

    private func delta(for dimension: Dimension?, first: Diagnosis, second: Diagnosis) -> DimensionDelta {
        guard let dimension else {
            return DimensionDelta(id: UUID(), dimension: .structure, before: .insufficient, after: .insufficient, beforeScore: 0, afterScore: 0, resolved: [], persisted: [], introduced: [], improvement: 0)
        }

        let beforeAssessment = first.assessment(for: dimension)
        let afterAssessment = second.assessment(for: dimension)
        let before = beforeAssessment?.findings ?? []
        let after = afterAssessment?.findings ?? []
        let afterByIdentity = Dictionary(after.map { ($0.identity, $0) }, uniquingKeysWith: { first, _ in first })
        let beforeIdentities = Set(before.map(\.identity))

        let persisted = before.compactMap { afterByIdentity[$0.identity] }
        let resolved = before.filter { afterByIdentity[$0.identity] == nil }
        let introduced = after.filter { !beforeIdentities.contains($0.identity) }
        let beforeScore = beforeAssessment?.score ?? 0
        let afterScore = afterAssessment?.score ?? 0
        let improvement = afterScore - beforeScore

        return DimensionDelta(
            id: UUID(),
            dimension: dimension,
            before: beforeAssessment?.band ?? .insufficient,
            after: afterAssessment?.band ?? .insufficient,
            beforeScore: beforeScore,
            afterScore: afterScore,
            resolved: resolved,
            persisted: persisted,
            introduced: introduced,
            improvement: improvement
        )
    }

    private func computeVerdict(primaryDelta: DimensionDelta?, newProblems: [DimensionDelta], overallImprovement: Double) -> ChallengeVerdict {
        guard let primaryDelta else { return .notYet }

        if primaryDelta.improvement >= 0.3 && primaryDelta.resolved.count >= primaryDelta.persisted.count {
            return newProblems.isEmpty ? .met : .closer
        }

        if primaryDelta.improvement > 0 && primaryDelta.resolved.count > 0 {
            return newProblems.isEmpty ? .closer : .closer
        }

        if primaryDelta.improvement >= -0.1 && newProblems.isEmpty {
            return .closer
        }

        return .notYet
    }

    private func challengeText(for dimension: Dimension, mode: ChallengeMode, basedOn findings: [Finding]) -> String {
        if findings.isEmpty {
            return mode == .continuation
                ? "Tell it again, and make sure this thread stays in."
                : "Tell it to a stranger, and make sure this thread stays in."
        }

        let subject = findings.first?.subject ?? dimension.title.lowercased()
        return mode == .continuation
            ? "Tell it again, and this time carry \(subject) through."
            : "Tell it to a stranger, and this time make sure \(subject) is clear from the start."
    }
}

private extension Band {
    static func score(band: Band) -> Double {
        switch band {
        case .insufficient: return 0
        case .emerging: return 0.3
        case .developing: return 0.6
        case .strong: return 1
        }
    }
}

// MARK: - Finding matching

extension Array where Element == Finding {
    func resolvedFindings(from previous: [Finding], in dimension: Dimension) -> [Finding] {
        previous.filter { previousFinding in
            !self.contains { currentFinding in
                currentFinding.subject == previousFinding.subject &&
                currentFinding.dimension == dimension &&
                abs(currentFinding.magnitude - previousFinding.magnitude) < 0.1
            }
        }
    }

    func persistedFindings(from previous: [Finding], in dimension: Dimension) -> [Finding] {
        self.filter { currentFinding in
            previous.contains { previousFinding in
                currentFinding.subject == previousFinding.subject &&
                currentFinding.dimension == dimension &&
                abs(currentFinding.magnitude - previousFinding.magnitude) < 0.1
            }
        }
    }

    func newFindings(comparedTo previous: [Finding], in dimension: Dimension) -> [Finding] {
        self.filter { currentFinding in
            !previous.contains { previousFinding in
                currentFinding.subject == previousFinding.subject &&
                currentFinding.dimension == dimension
            }
        }
    }
}
