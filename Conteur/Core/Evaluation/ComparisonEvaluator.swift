import Foundation

/// How the model did on one sample.
struct SampleScore: Sendable, Identifiable {
    let sample: RetellingSample
    let reported: Set<Int>
    let located: Set<Int>
    let inventedNames: [String]
    let conveyedStakes: Bool
    let failure: String?

    var id: String { sample.id }

    var expected: Set<Int> { sample.expectedBeats }
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

    var precision: Double { mean(\.precision) }
    var recall: Double { mean(\.recall) }
    var quoteYield: Double { mean(\.quoteYield) }

    var stakesAccuracy: Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.count { $0.stakesCorrect }) / Double(scores.count)
    }

    /// The worst failure mode: crediting the speaker with events they never told.
    var totalFalsePositives: Int {
        scores.reduce(0) { $0 + $1.falsePositives.count }
    }

    var totalFalseNegatives: Int {
        scores.reduce(0) { $0 + $1.falseNegatives.count }
    }

    var failures: [SampleScore] { scores.filter { $0.failure != nil } }

    func scores(for shape: RetellingSample.Shape) -> [SampleScore] {
        scores.filter { $0.sample.shape == shape }
    }

    private func mean(_ path: KeyPath<SampleScore, Double>) -> Double {
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0) { $0 + $1[keyPath: path] } / Double(scores.count)
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
                inventedNames: [],
                conveyedStakes: false,
                failure: "no story with id \(sample.storyID)"
            )
        }

        do {
            let comparison = try await comparer.compare(sample.transcript, with: story)
            return SampleScore(
                sample: sample,
                reported: Set(comparison.covered.map(\.beat.id)),
                located: Set(comparison.located.map(\.beat.id)),
                inventedNames: comparison.inventedNames.map(\.name),
                conveyedStakes: comparison.conveyedStakes,
                failure: nil
            )
        } catch {
            return SampleScore(
                sample: sample,
                reported: [],
                located: [],
                inventedNames: [],
                conveyedStakes: false,
                failure: error.localizedDescription
            )
        }
    }
}
