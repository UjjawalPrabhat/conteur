import SwiftUI

struct RetellingDetailView: View {
    let retelling: StoredRetelling

    @State private var player = RecordingPlayer()
    @State private var isPlaying = false

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
                playback
            }
            .padding()
        }
        .navigationTitle(retelling.recordedAt.formatted(.dateTime.day().month()))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: isPlaying)
        .onDisappear { stop() }
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
                            Text(Band(score: score).rawValue.capitalized)
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }

    /// Recordings live only on the device that made them, so an entry synced from
    /// elsewhere — or one whose audio was cleared — has nothing to play.
    @ViewBuilder
    private var playback: some View {
        if let audio = retelling.audio, FileManager.default.fileExists(atPath: audio.path) {
            Button {
                isPlaying ? stop() : start(audio)
            } label: {
                Label(
                    isPlaying ? "Stop" : "Hear it back",
                    systemImage: isPlaying ? "stop.circle" : "play.circle"
                )
            }
            .buttonStyle(.borderedProminent)
        } else {
            Text("The recording for this one is no longer on this iPhone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func labelled(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func start(_ audio: URL) {
        isPlaying = true
        Task {
            let remaining = try? await player.play(audio, from: 0)
            try? await Task.sleep(for: .seconds(remaining ?? 0))
            await player.stop()
            isPlaying = false
        }
    }

    private func stop() {
        isPlaying = false
        Task { await player.stop() }
    }
}
