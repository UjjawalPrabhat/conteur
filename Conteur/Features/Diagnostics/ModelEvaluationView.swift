import SwiftUI

/// Runs the scripted corpus through the real on-device model and reports how well it agreed
/// with the known answers.
///
/// This is the only way to see what the model actually does: it cannot run in the simulator,
/// so the numbers have to be produced on a device and read off afterwards.
struct ModelEvaluationView: View {
    @State private var model = ModelEvaluationViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let summary = model.summary {
                    headline(summary)
                    byShape(summary)
                    perSample(summary)
                } else {
                    Section {
                        Text("Runs \(RetellingCorpus.all.count) written-out retellings against the real model and scores its coverage against the known answer.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Model evaluation")
            .safeAreaInset(edge: .bottom) { controls }
        }
    }

    private func headline(_ summary: EvaluationSummary) -> some View {
        Section("Overall") {
            row("Precision", percent(summary.precision), note: "of what it said was told, how much was")
            row("Recall", percent(summary.recall), note: "of what was told, how much it found")
            row("Quote yield", percent(summary.quoteYield), note: "quotes findable in the retelling")
            row("Stakes", percent(summary.stakesAccuracy), note: "agreed on whether the point came through")
            row("Credited wrongly", "\(summary.totalFalsePositives)", note: "events it said were told that weren't")
            row("Missed", "\(summary.totalFalseNegatives)", note: "events told that it reported as omitted")
            row("Answered", "\(summary.answered.count) of \(summary.scores.count)", note: "\(summary.refused.count) refused by the guardrail")
        }
    }

    private func byShape(_ summary: EvaluationSummary) -> some View {
        Section("By shape") {
            ForEach(RetellingSample.Shape.allCases, id: \.self) { shape in
                let scores = summary.scores(for: shape).filter { $0.failure == nil }
                if !scores.isEmpty {
                    let precision = scores.reduce(0) { $0 + $1.precision } / Double(scores.count)
                    let recall = scores.reduce(0) { $0 + $1.recall } / Double(scores.count)
                    HStack {
                        Text(shape.rawValue.capitalized)
                        Spacer()
                        Text("P \(percent(precision)) · R \(percent(recall))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func perSample(_ summary: EvaluationSummary) -> some View {
        Section("Each sample") {
            ForEach(summary.scores) { score in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(score.sample.storyID) · \(score.sample.shape.rawValue)")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        if score.failure != nil {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                    if let failure = score.failure {
                        Text(failure).font(.caption).foregroundStyle(.orange)
                    } else {
                        Text("expected \(list(score.expected)) · got \(list(score.reported))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        if !score.falsePositives.isEmpty {
                            Text("credited wrongly: \(list(score.falsePositives))")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if !score.falseNegatives.isEmpty {
                            Text("missed: \(list(score.falseNegatives))")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if !score.inventedNames.isEmpty {
                            Text("invented: \(score.inventedNames.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            if model.isRunning {
                ProgressView(value: model.progress) {
                    Text("\(model.completed) of \(RetellingCorpus.all.count)")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            Button(model.summary == nil ? "Run evaluation" : "Run again") {
                Task { await model.run() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isRunning)
        }
        .padding()
        .background(.bar)
    }

    private func row(_ title: String, _ value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value).monospacedDigit()
            }
            Text(note).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func list(_ beats: Set<Int>) -> String {
        beats.isEmpty ? "none" : beats.sorted().map(String.init).joined(separator: ",")
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}
