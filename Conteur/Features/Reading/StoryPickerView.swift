import SwiftUI

struct StoryPickerView: View {
    let onChosen: (GuidedStory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Deliberately not a row in the list: inside an inset-grouped section a single
            // line of text renders as a rounded capsule and gets mistaken for a search field.
            Text("Read a story, then tell it back from memory.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            List {
                // Grouped by genre rather than by difficulty. Genre sets what a listener
                // expects to hear back, and the rules already use it; the difficulty ladder
                // that used to be here was asserted rather than measured.
                ForEach(stocked, id: \.self) { genre in
                    Section(genre.label) {
                        ForEach(StoryLibrary.stories(in: genre)) { story in
                            Button {
                                onChosen(story)
                            } label: {
                                row(for: story)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pick a story")
    }

    private var stocked: [Genre] {
        Genre.allCases.filter { !StoryLibrary.stories(in: $0).isEmpty }
    }

    private func row(for story: GuidedStory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(story.title)
                .font(.headline)
            Text("\(story.wordCount) words · about \(Int(story.readingTime.rounded()))s to read")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
