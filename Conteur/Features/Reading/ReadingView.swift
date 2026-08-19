import SwiftUI

/// The story, to read once.
///
/// It goes away before the retelling starts and does not come back. Retelling from memory
/// is the paradigm the recall research is built on, and it is also the only version that
/// resembles talking about something you actually read.
struct ReadingView: View {
    let story: GuidedStory
    let onFinished: () -> Void

    @State private var hasReachedEnd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Text(story.prose)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                // Marking the end of the text rather than the end of the scroll view, so
                // the button appears when the story has been read, not when it is on screen.
                Color.clear
                    .frame(height: 1)
                    .onAppear { hasReachedEnd = true }

                closing
            }
            .padding(24)
        }
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(story.title)
                .font(.largeTitle.weight(.semibold))
            HStack(spacing: 10) {
                Text(story.genre.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.12), in: .capsule)
                Text("about \(Int(story.readingTime.rounded())) seconds to read")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Read it once. It won't be here afterwards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var closing: some View {
        if hasReachedEnd {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                Text("Ready to tell it back?")
                    .font(.headline)
                Button("I've read it", action: onFinished)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .transition(.opacity)
        }
    }
}
