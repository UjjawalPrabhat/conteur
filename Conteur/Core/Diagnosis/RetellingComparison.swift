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

        // The second telling has to be judgeable on the dimension the challenge targeted.
        // A dimension nothing could evaluate produces no findings, and no findings is
        // indistinguishable from the problem being fixed — so a retelling too sparse to look
        // at would be credited with meeting a challenge nobody measured. No verdict is the
        // honest answer, and the feedback screen already shows a telling without one.
        guard
            let retold = second.assessment(for: focus.dimension),
            retold.band != .insufficient
        else { return nil }

        let before = focus.findings
        let after = retold.findings
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

    /// Gone is met. Still there but smaller is progress, and saying otherwise would tell
    /// somebody who improved that they failed. Still there and unchanged is not yet.
    ///
    /// Each finding is compared against its own earlier self and never summed with another.
    /// Magnitudes are only meaningful within one rule — a stall count of 4 and a pitch
    /// shortfall of 0.02 measure different things on different scales, and adding them makes
    /// the count decide the verdict on its own.
    private func verdict(before: [Finding], persisted: [Finding]) -> ChallengeVerdict {
        guard !persisted.isEmpty else { return .met }

        let earlier = Dictionary(
            before.map { ($0.identity, $0.magnitude) },
            uniquingKeysWith: { first, _ in first }
        )
        let improved = persisted.count { finding in
            guard let was = earlier[finding.identity], was > 0 else { return false }
            return (was - finding.magnitude) / was >= Self.meaningfulImprovement
        }

        // Half is enough: two problems, one of them halved, is a telling that moved. Nothing
        // improved can never reach it, which is the only case that must not read as progress.
        return improved * 2 >= persisted.count ? .closer : .notYet
    }
}
