import SwiftData
import SwiftUI

struct BookDetailView: View {
    @Environment(\.modelContext) private var context
    let book: BookSession

    @State private var bookContext: SwiftDataBookContext?

    var body: some View {
        List {
            summarySection
            entityRegistrySection
            recentEventsSection
        }
        .navigationTitle(book.title)
        .task {
            bookContext = SwiftDataBookContext(context: context)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        Section {
            LabeledContent("Shape", value: book.shape.title)
            LabeledContent("Sessions", value: "\(book.lastSessionNumber)")
            LabeledContent("Started", value: book.startedAt, format: .dateTime.day().month().year())
            LabeledContent("Entities", value: "\(book.entityRegistry.count)")
        } header: {
            Text("Book")
        }
    }

    @ViewBuilder
    private var entityRegistrySection: some View {
        if book.entityRegistry.isEmpty {
            Section("Entities") {
                ContentUnavailableView(
                    "No entities yet",
                    systemImage: "person.3",
                    description: Text("Entities will appear as they are introduced.")
                )
            }
        } else {
            Section("Entities") {
                ForEach(book.entityRegistry) { entity in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entity.name)
                            .font(.headline)
                        Text("Mentions: \(entity.mentionCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let first = entity.emotionalAssociations.first {
                            Text("Recent emotion: \(first.emotion.title)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentEventsSection: some View {
        let events = book.events.sorted { $0.timestamp < $1.timestamp }.suffix(20)
        if events.isEmpty {
            Section("Recent events") {
                ContentUnavailableView(
                    "No events yet",
                    systemImage: "waveform",
                    description: Text("Events will appear after your first retelling.")
                )
            }
        } else {
            Section("Recent events") {
                ForEach(Array(events)) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.kind.title)
                            .font(.caption.weight(.semibold))
                        Text(event.subject)
                            .font(.subheadline)
                        if !event.detailText.isEmpty {
                            Text(event.detailText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(event.timestamp.formatted(.number.precision(.fractionLength(1))) + "s")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private extension StoryShape {
    var title: String {
        switch self {
        case .plotDriven: "Plot driven"
        case .characterDriven: "Character driven"
        case .thematic: "Thematic"
        case .episodic: "Episodic"
        }
    }
}

private extension EventKind {
    var title: String {
        switch self {
        case .entityIntroduced: "Entity introduced"
        case .entityReferenced: "Entity referenced"
        case .componentCovered: "Component covered"
        case .stakesStated: "Stakes stated"
        case .emotionalMatch: "Emotional match"
        case .emotionalMismatch: "Emotional mismatch"
        case .emotionalAdjacent: "Emotional adjacent"
        }
    }
}

private extension DetectedEmotion {
    var title: String {
        switch self {
        case .joy: "Joy"
        case .sadness: "Sadness"
        case .anger: "Anger"
        case .fear: "Fear"
        case .surprise: "Surprise"
        case .tension: "Tension"
        case .relief: "Relief"
        case .neutral: "Neutral"
        }
    }
}
