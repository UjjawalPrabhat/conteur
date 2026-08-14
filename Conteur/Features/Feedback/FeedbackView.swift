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
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    note
                    evidence
                    challenge
                    bands
                    transcript
                }
                .padding()
            }
            .navigationTitle("How you told it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.stopReplay()
                        onDone()
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: model.playing)
        }
    }

    @ViewBuilder
    private var note: some View {
        if let feedback = model.feedback {
            Text(feedback.note)
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Every claim points at a moment you can go and hear. Without this the feedback
    /// is an opinion; with it, it is a receipt.
    @ViewBuilder
    private var evidence: some View {
        if let feedback = model.feedback, !feedback.evidence.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Where")
                    .font(.headline)
                    .padding(.bottom, 8)

                ForEach(Array(feedback.evidence.enumerated()), id: \.offset) { _, item in
                    PlayableRow(isPlaying: model.isPlaying(item.at)) {
                        model.replay(from: item.at)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(item.at.timestampLabel)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                if let quote = item.quote {
                                    Text(quote)
                                }
                                if let measure = item.measure {
                                    Text(measure)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var challenge: some View {
        if let feedback = model.feedback {
            VStack(alignment: .leading, spacing: 8) {
                Text("Try again")
                    .font(.headline)
                Text(feedback.challenge)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Tell it again") {
                    model.stopReplay()
                    onRetell()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding()
            .background(.tint.opacity(0.08), in: .rect(cornerRadius: 12))
        }
    }

    private var bands: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Everything else")
                .font(.headline)

            ForEach(model.bands, id: \.dimension) { assessment in
                HStack {
                    Text(assessment.dimension.title)
                    Spacer()
                    Text(assessment.band.rawValue.capitalized)
                        .foregroundStyle(assessment.dimension == model.feedback?.dimension ? .primary : .secondary)
                }
                .font(.callout)
            }
        }
    }

    @ViewBuilder
    private var transcript: some View {
        if !model.passages.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("What you said")
                    .font(.headline)
                    .padding(.bottom, 8)

                ForEach(model.passages) { passage in
                    PlayableRow(isPlaying: model.isPlaying(passage.start)) {
                        model.replay(from: passage.start)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(passage.start.timestampLabel)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Text(passage.text)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }
        }
    }
}

/// A row that plays a moment back, and looks like it is doing so.
private struct PlayableRow<Label: View>: View {
    let isPlaying: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                label
                Spacer(minLength: 0)
                Image(systemName: isPlaying ? "waveform" : "play.circle")
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                isPlaying ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear),
                in: .rect(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isPlaying)
    }
}
