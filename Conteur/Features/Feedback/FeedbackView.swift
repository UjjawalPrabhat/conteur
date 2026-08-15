import SwiftUI

struct FeedbackView: View {
    @State private var model: FeedbackViewModel
    private let onRetell: () -> Void
    private let onDone: () -> Void

    init(
        assessment: Assessment,
        onRetell: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        _model = State(initialValue: FeedbackViewModel(assessment: assessment))
        self.onRetell = onRetell
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        whatChanged
                        note
                        evidence(scrollingWith: scroll)
                        challenge
                        bands
                        transcript
                    }
                    .padding()
                }
            }
            .navigationTitle("How you told it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
            .sensoryFeedback(.selection, trigger: model.highlighted)
        }
    }

    /// Shown from the second telling on. The verdict is computed, never written, so it
    /// can say the attempt missed.
    @ViewBuilder
    private var whatChanged: some View {
        if let progress = model.assessment.progress {
            VStack(alignment: .leading, spacing: 12) {
                Text("You were asked")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(progress.challenge)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Image(systemName: progress.verdict.symbol)
                    Text(progress.verdict.label)
                        .font(.headline)
                    Spacer()
                    Text("\(progress.before.label) → \(progress.after.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(progress.verdict.tint)

                ForEach(progress.resolved, id: \.identity) { finding in
                    changeRow(finding.observation, symbol: "checkmark")
                }
                ForEach(progress.persisted, id: \.identity) { finding in
                    changeRow(finding.observation, symbol: "arrow.turn.down.right")
                }
                ForEach(progress.introduced, id: \.identity) { finding in
                    changeRow(finding.observation, symbol: "exclamationmark")
                }
            }
            .padding()
            .background(progress.verdict.tint.opacity(0.1), in: .rect(cornerRadius: 12))
        }
    }

    private func changeRow(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var note: some View {
        Text(model.feedback?.note ?? "There wasn't enough in that one for me to say much about how you told it.")
            .font(.title3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Every claim points at the words it came from. Without that the feedback is an
    /// opinion; with it, the reader can go and check.
    @ViewBuilder
    private func evidence(scrollingWith scroll: ScrollViewProxy) -> some View {
        if let feedback = model.feedback, !feedback.evidence.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Where")
                    .font(.headline)
                    .padding(.bottom, 8)

                ForEach(Array(feedback.evidence.enumerated()), id: \.offset) { _, item in
                    Button {
                        model.reveal(item.at)
                        withAnimation {
                            scroll.scrollTo(model.passage(covering: item.at)?.start, anchor: .center)
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(item.at.timestampLabel)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                if let quote = item.quote {
                                    Text(quote).multilineTextAlignment(.leading)
                                }
                                if let measure = item.measure {
                                    Text(measure)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "text.quote")
                                .foregroundStyle(.tint)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Always present. The way back into the loop must not depend on there having been
    /// something wrong.
    private var challenge: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try again")
                .font(.headline)
            Text(model.feedback?.challenge ?? "Tell it again, and give it a bit more room this time.")
                .fixedSize(horizontal: false, vertical: true)

            Button("Tell it again", action: onRetell)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding()
        .background(.tint.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    private var bands: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Everything else")
                .font(.headline)

            ForEach(model.bands, id: \.dimension) { assessment in
                HStack {
                    Text(assessment.dimension.title)
                    Spacer()
                    Text(assessment.band.label)
                        .foregroundStyle(assessment.dimension == model.feedback?.dimension ? .primary : .secondary)
                }
                .font(.callout)
            }
        }
    }

    @ViewBuilder
    private var transcript: some View {
        if !model.passages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("What you said")
                    .font(.headline)

                ForEach(model.passages) { passage in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(passage.start.timestampLabel)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(passage.text)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(
                        model.highlighted == passage.start
                            ? AnyShapeStyle(.tint.opacity(0.14))
                            : AnyShapeStyle(.clear),
                        in: .rect(cornerRadius: 10)
                    )
                    .animation(.easeOut(duration: 0.25), value: model.highlighted)
                    .id(passage.start)
                }
            }
        }
    }
}
