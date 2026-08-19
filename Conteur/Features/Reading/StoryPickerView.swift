import SwiftUI

struct StoryPickerView: View {
    let onChosen: (GuidedStory) -> Void

    var body: some View {
        List {
            Section {
                Text("Read a story, then tell it back from memory.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(levels, id: \.self) { level in
                Section("Level \(level)") {
                    ForEach(StoryLibrary.stories(at: level)) { story in
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
        .navigationTitle("Pick a story")
    }

    private var levels: [Int] {
        Array(Set(StoryLibrary.all.map(\.level))).sorted()
    }

    private func row(for story: GuidedStory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(story.title)
                .font(.headline)
            Text("\(story.genre.label) · \(story.wordCount) words · about \(Int(story.readingTime.rounded()))s to read")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
