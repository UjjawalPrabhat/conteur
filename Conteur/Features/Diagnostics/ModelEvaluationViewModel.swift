import Foundation
import Observation

@MainActor
@Observable
final class ModelEvaluationViewModel {
    private(set) var summary: EvaluationSummary?
    private(set) var isRunning = false
    private(set) var completed = 0

    private let evaluator = ComparisonEvaluator()

    var progress: Double {
        let total = RetellingCorpus.all.count
        return total > 0 ? Double(completed) / Double(total) : 0
    }

    /// Scored one sample at a time so the count moves — each one is a separate model session
    /// and the whole corpus takes a while.
    func run() async {
        guard !isRunning else { return }
        isRunning = true
        completed = 0
        summary = nil

        var scores: [SampleScore] = []
        for sample in RetellingCorpus.all {
            scores.append(contentsOf: await evaluator.evaluate([sample]).scores)
            completed += 1
        }

        summary = EvaluationSummary(scores: scores)
        isRunning = false
    }
}
