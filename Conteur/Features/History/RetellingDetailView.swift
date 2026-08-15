import SwiftUI

struct RetellingDetailView: View {
    let retelling: StoredRetelling

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let note = retelling.note {
                    Text(note)
                        .font(.title3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let challenge = retelling.challenge {
                    labelled("What to try", challenge)
                }
                scores
                transcript
            }
            .padding()
        }
        .navigationTitle(retelling.recordedAt.formatted(.dateTime.day().month()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            if let focus = retelling.focusDimension {
                Text(focus.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.12), in: .capsule)
            }
            if retelling.attempt > 1 {
                Text("second telling")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(retelling.wordCount) words · \(retelling.duration.secondsLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var scores: some View {
        let scores = retelling.scores
        if !scores.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("How it read")
                    .font(.headline)
                ForEach(Dimension.allCases, id: \.self) { dimension in
                    if let score = scores[dimension] {
                        HStack {
                            Text(dimension.title)
                            Spacer()
                            Text(Band(score: score).label)
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }

    /// The transcript is the whole record of a retelling — the audio it came from was
    /// never written anywhere.
    @ViewBuilder
    private var transcript: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What you said")
                .font(.headline)

            if let text = retelling.transcriptText, !text.isEmpty {
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } else {
                Text("No transcript was kept for this one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func labelled(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).fixedSize(horizontal: false, vertical: true)
        }
    }
}
