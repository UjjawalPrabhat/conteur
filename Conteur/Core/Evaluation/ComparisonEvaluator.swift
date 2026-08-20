import Foundation
import FoundationModels

/// How the model did on one sample.
struct SampleScore: Sendable, Identifiable {
    let sample: RetellingSample
    let reported: Set<Int>
    let located: Set<Int>
    /// Events the model would not judge. Scored as neither hit nor miss, for the same reason a
    /// refused sample is left out of the averages: it says nothing about the model's judgement.
    let unresolved: Set<Int>
    let inventedNames: [String]
    let conveyedStakes: Bool
    let failure: String?
    /// Why it produced nothing, when it produced nothing. Kept apart from a wrong answer,
    /// because averaging a refusal in as zero hid what the model was doing on the samples it
    /// did answer.
    let failureKind: ModelFailure?

    var id: String { sample.id }

    var expected: Set<Int> { sample.expectedBeats.subtracting(unresolved) }
    var hits: Set<Int> { reported.intersection(expected) }
    /// Events the model claimed were told that were not. The dangerous direction: it credits
    /// the speaker with something they never said.
    var falsePositives: Set<Int> { reported.subtracting(expected) }
    /// Events the speaker told that the model missed. Reported to them as an omission.
    var falseNegatives: Set<Int> { expected.subtracting(reported) }

    var precision: Double {
        reported.isEmpty ? (expected.isEmpty ? 1 : 0) : Double(hits.count) / Double(reported.count)
    }

    var recall: Double {
        expected.isEmpty ? (reported.isEmpty ? 1 : 0) : Double(hits.count) / Double(expected.count)
    }

    /// How often a quote the model produced could actually be found in the retelling. Low
    /// here means the feedback loses its ability to point anywhere, even when coverage is right.
    var quoteYield: Double {
        reported.isEmpty ? 1 : Double(located.count) / Double(reported.count)
    }

    var stakesCorrect: Bool { conveyedStakes == sample.expectedStakes }
}

struct EvaluationSummary: Sendable {
    let scores: [SampleScore]

    /// Only the samples the model actually answered. A refusal is not a wrong answer.
    var answered: [SampleScore] { scores.filter { $0.failure == nil } }
    func failed(_ kind: ModelFailure) -> [SampleScore] {
        scores.filter { $0.failureKind == kind }
    }

    var precision: Double { mean(\.precision) }
    var recall: Double { mean(\.recall) }
    var quoteYield: Double { mean(\.quoteYield) }

    var stakesAccuracy: Double {
        guard !answered.isEmpty else { return 0 }
        return Double(answered.count { $0.stakesCorrect }) / Double(answered.count)
    }

    /// The worst failure mode: crediting the speaker with events they never told.
    var totalFalsePositives: Int {
        answered.reduce(0) { $0 + $1.falsePositives.count }
    }

    var totalFalseNegatives: Int {
        answered.reduce(0) { $0 + $1.falseNegatives.count }
    }

    /// Events no judgement came back for. Worth watching rather than averaging: a run where
    /// many events go unjudged is a run whose feedback is quietly thin.
    var totalUnresolved: Int {
        answered.reduce(0) { $0 + $1.unresolved.count }
    }

    var failures: [SampleScore] { scores.filter { $0.failure != nil } }

    func scores(for shape: RetellingSample.Shape) -> [SampleScore] {
        scores.filter { $0.sample.shape == shape }
    }

    private func mean(_ path: KeyPath<SampleScore, Double>) -> Double {
        guard !answered.isEmpty else { return 0 }
        return answered.reduce(0) { $0 + $1[keyPath: path] } / Double(answered.count)
    }
}

/// Runs the corpus through a comparer and scores it.
///
/// Deliberately separate from the comparer it measures, and pure apart from the calls it
/// makes, so the scoring can be tested without a model even though the thing being scored
/// cannot be.
struct ComparisonEvaluator: Sendable {
    private let comparer: any SourceComparing

    init(comparer: any SourceComparing = StoryComparison()) {
        self.comparer = comparer
    }

    func evaluate(_ samples: [RetellingSample] = RetellingCorpus.all) async -> EvaluationSummary {
        var scores: [SampleScore] = []
        for sample in samples {
            scores.append(await score(sample))
        }
        return EvaluationSummary(scores: scores)
    }

    private func score(_ sample: RetellingSample) async -> SampleScore {
        guard let story = sample.story else {
            return SampleScore(
                sample: sample,
                reported: [],
                located: [],
                unresolved: [],
                inventedNames: [],
                conveyedStakes: false,
                failure: "no story with id \(sample.storyID)",
                failureKind: .other
            )
        }

        do {
            let comparison = try await comparer.compare(sample.transcript, with: story)
            return SampleScore(
                sample: sample,
                reported: Set(comparison.covered.map(\.beat.id)),
                located: Set(comparison.located.map(\.beat.id)),
                unresolved: Set(comparison.unresolved.map(\.id)),
                inventedNames: comparison.inventedNames.map(\.name),
                conveyedStakes: comparison.conveyedStakes,
                failure: nil,
                failureKind: nil
            )
        } catch {
            let kind = ModelFailure(error)
            return SampleScore(
                sample: sample,
                reported: [],
                located: [],
                unresolved: [],
                inventedNames: [],
                conveyedStakes: false,
                failure: kind == .other ? error.localizedDescription : kind.label,
                failureKind: kind
            )
        }
    }
}
