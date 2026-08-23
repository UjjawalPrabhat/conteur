import SwiftData
import SwiftUI

/// Everything the app has counted, with nothing summarised away.
///
/// The Progress screen picks one thing to say; this is the other half of the same promise —
/// if the app is going to draw a conclusion, the numbers behind it have to be reachable.
struct EveryNumberView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var model: ProgressViewModel?

    var body: some View {
        ScrollView {
            if let model {
                VStack(alignment: .leading, spacing: Space.screen) {
                    Text("Every number")
                        .textStyle(.screenTitle)
                        .foregroundStyle(Ink.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    totals(model)
                    dimensions(model)
                    folds(model)
                }
                .screenPadding()
                .padding(.top, Space.l)
                .padding(.bottom, Space.section)
            }
        }
        .scrollIndicators(.hidden)
        .background(NightBackground())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack {
                BackButton(title: "Progress") { dismiss() }
                Spacer()
            }
            .screenPadding()
            .padding(.bottom, Space.s)
        }
        .task {
            let model = model ?? ProgressViewModel(context: context)
            self.model = model
            model.load()
        }
    }

    private func totals(_ model: ProgressViewModel) -> some View {
        let report = model.report
        return VStack(spacing: Space.l) {
            HStack(alignment: .top, spacing: Space.l) {
                StatFigure(value: "\(report.tellings)", caption: "tellings")
                StatFigure(value: model.wordsLabel, caption: "words told")
            }
            HStack(alignment: .top, spacing: Space.l) {
                StatFigure(value: model.timeLabel, caption: "at the fire")
                StatFigure(value: "\(report.retoldTwice)", caption: "retold twice")
            }
        }
    }

    private func dimensions(_ model: ProgressViewModel) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("Six dimensions").eyebrowStyle()
                Spacer()
                Text("vs 4-week avg")
                    .textStyle(.categoryLabel)
                    .foregroundStyle(Ink.quaternary)
            }
            // Biggest mover first. Alphabetical would bury the only rows worth reading.
            let deltas = sorted(model.report.deltas)
            VStack(spacing: 0) {
                ForEach(deltas) { delta in
                    if delta.id != deltas.first?.id {
                        Rectangle().fill(Surface.dividerQuiet).frame(height: 1)
                    }
                    DeltaRow(title: delta.dimension.title, change: delta.change)
                }
            }
            .cardSurface(Surface.finding)
        }
    }

    private func sorted(_ deltas: [DimensionDelta]) -> [DimensionDelta] {
        deltas.sorted { ($0.change ?? -.infinity) > ($1.change ?? -.infinity) }
    }

    private func folds(_ model: ProgressViewModel) -> some View {
        VStack(spacing: Space.m) {
            FoldedRow(title: "Pace over time", trailing: model.paceLabel) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Sparkline(values: model.report.pace.map(\.wordsPerMinute))
                    if let ends = model.paceEnds {
                        HStack {
                            Text(ends.earliest)
                            Spacer()
                            Text(ends.latest)
                        }
                        .textStyle(.stats)
                        .foregroundStyle(Ink.tertiary)
                    }
                }
            }

            FoldedRow(title: "Already true of you", trailing: "\(model.report.alreadyTrue.count)") {
                VStack(alignment: .leading, spacing: Space.m) {
                    ForEach(model.report.alreadyTrue) { claim in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(claim.statement)
                                .textStyle(.secondary)
                                .foregroundStyle(Ink.primary)
                            Text(claim.evidence)
                                .textStyle(.stats)
                                .foregroundStyle(Ink.quaternary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let hour = model.bestHourLabel {
                FoldedRow(title: "When you tell best", trailing: hour) {
                    Text("Averaged across every dimension, your tellings around \(hour) score highest. Two sessions in an hour is the least this is drawn from, so treat it as a hint rather than a habit.")
                        .textStyle(.secondary)
                        .foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            FoldedRow(title: "By story category", trailing: "\(model.report.byGenre.count)") {
                VStack(spacing: Space.s) {
                    ForEach(model.report.byGenre) { tally in
                        HStack {
                            Text(tally.genre.label)
                                .textStyle(.secondary)
                                .foregroundStyle(Ink.primary)
                            Spacer()
                            Text("\(tally.tellings)")
                                .textStyle(.stats)
                                .foregroundStyle(Color.moonlight)
                        }
                    }
                    if model.report.byGenre.isEmpty {
                        Text("Older tellings did not record which story they were, so they are not counted here.")
                            .textStyle(.secondary)
                            .foregroundStyle(Ink.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Branch-only tooling: the only way to re-measure the comparison algorithm on a
            // device when a rule changes. Debug builds only — a release reader has no use for
            // a screen that spends a few minutes of model time to print a precision figure.
            #if DEBUG
            FoldedRow(title: "Model evaluation", trailing: "developer") {
                NavigationLink {
                    ModelEvaluationView()
                } label: {
                    HStack {
                        Text("Run the corpus")
                            .textStyle(.actionQuiet)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.ember)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            #endif
        }
    }
}
