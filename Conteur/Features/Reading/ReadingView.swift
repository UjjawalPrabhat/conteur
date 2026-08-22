import SwiftUI

/// The story, to read once.
///
/// It goes away before the retelling starts and does not come back. Retelling from memory
/// is the paradigm the recall research is built on, and it is also the only version that
/// resembles talking about something you actually read.
struct ReadingView: View {
    let story: GuidedStory
    let onBack: () -> Void
    let onFinished: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header
                    Callout(text: "Read it once. It won't be here afterwards.")
                    prose
                }
                .screenPadding()
                .padding(.top, Space.l)
                // Room for the scrim and the button, so the last paragraph is never
                // trapped underneath them.
                .padding(.bottom, 150)
            }
            .scrollIndicators(.hidden)

            closing
        }
        .background(NightBackground())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack {
                BackButton(title: "Stories", action: onBack)
                Spacer()
            }
            .screenPadding()
            .padding(.bottom, Space.s)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(story.title)
                .textStyle(.storyTitle)
                .foregroundStyle(Ink.primary)
            Text("\(story.genre.label) · about \(Int(story.readingTime.rounded())) seconds to read")
                .textStyle(.meta)
                .foregroundStyle(Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var prose: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .textStyle(.storyBody)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var paragraphs: [String] {
        story.prose
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Always available. Gating it on having scrolled to the end measured whether the text
    /// had been on screen, not whether it had been read, and left anybody who skims stuck on
    /// a screen with no way forward.
    private var closing: some View {
        VStack(spacing: Space.m) {
            Text("That's the whole story. It won't be here once you begin.")
                .textStyle(.secondary)
                .foregroundStyle(Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            IgniteControl(onIgnite: onFinished)
            Text("press and hold")
                .textStyle(.categoryLabel)
                .foregroundStyle(Ink.quaternary)
        }
        .screenPadding()
        .padding(.bottom, Space.s)
        .padding(.top, Space.section)
        .background {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color.nightDeep.opacity(0.94), location: 0.34),
                    .init(color: Color.nightDeep.opacity(0.94), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
