import SwiftUI

struct StoryPickerView: View {
    let onChosen: (GuidedStory) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.screen) {
                title
                // Grouped by genre rather than by difficulty. Genre sets what a listener
                // expects to hear back, and the rules already use it; the difficulty ladder
                // that used to be here was asserted rather than measured.
                ForEach(stocked, id: \.self) { genre in
                    group(genre)
                }
            }
            .screenPadding()
            .padding(.top, Space.section)
            .padding(.bottom, Space.section)
        }
        .background(NightBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var stocked: [Genre] {
        Genre.allCases.filter { !StoryLibrary.stories(in: $0).isEmpty }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Pick a story")
                .textStyle(.largeTitle)
                .foregroundStyle(Ink.primary)
            Text("Read a story, then tell it back from memory.")
                .textStyle(.body)
                .foregroundStyle(Ink.secondary)
                .frame(maxWidth: 280, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func group(_ genre: Genre) -> some View {
        let stories = StoryLibrary.stories(in: genre)
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text(genre.label).eyebrowStyle()

            VStack(spacing: 0) {
                ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                    if index > 0 {
                        Rectangle()
                            .fill(Surface.divider)
                            .frame(height: 1)
                    }
                    Button {
                        onChosen(story)
                    } label: {
                        // The first row of the first group is where a reader with no
                        // preference should land, so it is tinted rather than left to be
                        // chosen at random.
                        row(story, isSuggested: index == 0 && genre == stocked.first)
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardSurface()
        }
    }

    private func row(_ story: GuidedStory, isSuggested: Bool) -> some View {
        HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(story.title)
                    .textStyle(.rowTitle)
                    .foregroundStyle(Ink.primary)
                Text("\(story.wordCount) words · about \(Int(story.readingTime.rounded()))s to read")
                    .textStyle(.meta)
                    .foregroundStyle(Ink.tertiary)
            }
            Spacer(minLength: Space.s)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.tertiary)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, Space.lg)
        .background(isSuggested ? Surface.emberRow : .clear)
    }
}
