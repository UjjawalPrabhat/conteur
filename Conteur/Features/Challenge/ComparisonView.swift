import SwiftUI

/// Attempt one against attempt two, on the one dimension the challenge targeted.
///
/// Deliberately narrow: showing every dimension invites reading noise as movement.
/// Because the diagnosis is deterministic, a change here is a real change.
struct ComparisonView: View {
    let first: Assessment
    let second: Assessment
    let onDone: () -> Void

    @State private var player = RecordingPlayer()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let dimension = first.focus {
                        verdict(for: dimension)
                        change(for: dimension)
                    }
                    recordings
                }
                .padding()
            }
            .navigationTitle("Then and now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task { await player.stop() }
                        onDone()
                    }
                }
            }
        }
    }

    private func verdict(for dimension: Dimension) -> some View {
        let before = first.diagnosis.assessment(for: dimension)
        let after = second.diagnosis.assessment(for: dimension)

        return VStack(alignment: .leading, spacing: 8) {
            Text(dimension.title)
                .font(.headline)
            HStack(spacing: 12) {
                Text(before?.band.rawValue.capitalized ?? "—")
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Text(after?.band.rawValue.capitalized ?? "—")
                    .fontWeight(.semibold)
            }
            .font(.title3)

            Text(summary(before: before, after: after))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func summary(before: DimensionAssessment?, after: DimensionAssessment?) -> String {
        guard let before, let after else { return "" }
        let resolved = before.findings.count - after.findings.count

        return switch resolved {
        case 1...: "\(resolved) of what came up the first time didn't come up again."
        case ..<0: "More came up this time than last."
        default: "About the same as the first telling."
        }
    }

    @ViewBuilder
    private func change(for dimension: Dimension) -> some View {
        let after = second.diagnosis.assessment(for: dimension)?.findings ?? []

        if after.isEmpty {
            Text("Nothing came up on that this time.")
                .font(.callout)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Still there")
                    .font(.headline)
                ForEach(Array(after.enumerated()), id: \.offset) { _, finding in
                    Text(finding.observation)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var recordings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hear them back")
                .font(.headline)
            recording("First telling", assessment: first)
            recording("Second telling", assessment: second)
        }
    }

    private func recording(_ title: String, assessment: Assessment) -> some View {
        Button {
            Task { try? await player.play(assessment.audio, from: 0) }
        } label: {
            HStack {
                Image(systemName: "play.circle")
                Text(title)
                Spacer()
                Text(assessment.timeline.duration.secondsLabel)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }
}
