import SwiftUI

struct RetellingDetailView: View {
    let retelling: StoredRetelling

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                header
                if let note = retelling.note {
                    Text(note)
                        .textStyle(.summary)
                        .foregroundStyle(Color.paper.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let challenge = retelling.challenge {
                    Callout(text: challenge)
                }
                scores
                transcript
            }
            .screenPadding()
            .padding(.top, Space.l)
            .padding(.bottom, Space.section)
        }
        .scrollIndicators(.hidden)
        .background(NightBackground())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack {
                BackButton(title: "Retellings") { dismiss() }
                Spacer()
            }
            .screenPadding()
            .padding(.bottom, Space.s)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(retelling.storyTitle ?? "A story")
                .textStyle(.detailTitle)
                .foregroundStyle(Ink.primary)
            Text(meta)
                .textStyle(.meta)
                .foregroundStyle(Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var meta: String {
        var parts = [retelling.recordedAt.formatted(.dateTime.day().month().hour().minute())]
        if retelling.attempt > 1 { parts.append("second telling") }
        parts.append("\(retelling.wordCount) words")
        parts.append(retelling.duration.secondsLabel)
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var scores: some View {
        let scores = retelling.scores
        if !scores.isEmpty {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeading(title: "How it read")
                VStack(spacing: 0) {
                    ForEach(Array(rated(scores).enumerated()), id: \.element.dimension) { index, row in
                        if index > 0 {
                            Rectangle().fill(Surface.dividerQuiet).frame(height: 1)
                        }
                        HStack {
                            Text(row.dimension.title)
                                .textStyle(.rowTitle)
                                .foregroundStyle(Ink.primary)
                            Spacer()
                            if row.dimension == retelling.focusDimension {
                                Text("focus")
                                    .textStyle(.eyebrowSmall)
                                    .textCase(.lowercase)
                                    .foregroundStyle(Color.ember.opacity(0.7))
                            }
                            Pill(text: row.band.label, isStrong: row.band == .strong)
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, Space.l)
                    }
                }
                .cardSurface(Surface.finding)
            }
        }
    }

    private func rated(_ scores: [Dimension: Double]) -> [(dimension: Dimension, band: Band)] {
        Dimension.allCases.compactMap { dimension in
            scores[dimension].map { (dimension, Band(score: $0)) }
        }
    }

    /// The transcript is the whole record of a retelling — the audio it came from was
    /// never written anywhere.
    private var transcript: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeading(title: "What you said")
            if let text = retelling.transcriptText, !text.isEmpty {
                Text(text)
                    .textStyle(.transcript)
                    .foregroundStyle(Color.paper.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } else {
                Text("No transcript was kept for this one.")
                    .textStyle(.secondary)
                    .foregroundStyle(Ink.tertiary)
            }
        }
    }
}
