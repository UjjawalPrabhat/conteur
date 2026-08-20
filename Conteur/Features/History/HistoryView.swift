import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \StoredRetelling.recordedAt, order: .reverse)
    private var retellings: [StoredRetelling]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Retellings")
                        .textStyle(.largeTitle)
                        .foregroundStyle(Ink.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Space.m)

                    if retellings.isEmpty {
                        empty
                    } else {
                        ForEach(Array(retellings.enumerated()), id: \.element.id) { index, retelling in
                            NavigationLink {
                                RetellingDetailView(retelling: retelling)
                            } label: {
                                // The most recent telling sits slightly forward of the rest.
                                card(retelling, isLatest: index == 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .screenPadding()
                .padding(.top, Space.section)
                .padding(.bottom, Space.section)
            }
            .scrollIndicators(.hidden)
            .background(NightBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Nothing yet")
                .textStyle(.sectionHeading)
                .foregroundStyle(Ink.primary)
            Text("Your retellings will collect here.")
                .textStyle(.body)
                .foregroundStyle(Ink.secondary)
        }
        .padding(.top, Space.xl)
    }

    private func card(_ retelling: StoredRetelling, isLatest: Bool) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top) {
                Text(retelling.recordedAt, format: .dateTime.day().month().hour().minute())
                    .textStyle(.meta)
                    .foregroundStyle(Ink.tertiary)
                Spacer()
                if retelling.attempt > 1 {
                    Text("second telling")
                        .textStyle(.pillLabel)
                        .foregroundStyle(Color.emberLight)
                        .padding(.horizontal, Space.s)
                        .padding(.vertical, 3)
                        .background(Surface.emberPill, in: .rect(cornerRadius: Radius.pill))
                }
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(retelling.storyTitle ?? "A story")
                    .textStyle(.rowTitle)
                    .foregroundStyle(Ink.primary)
                if let focus = retelling.focusDimension {
                    Text("Focus · \(focus.title)")
                        .textStyle(.categoryLabel)
                        .textCase(.uppercase)
                        .foregroundStyle(Ink.tertiary)
                }
            }

            if let note = retelling.note {
                Text(note)
                    .textStyle(.excerpt)
                    .foregroundStyle(Color.paper.opacity(0.62))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Text("\(retelling.wordCount) words · \(retelling.duration.secondsLabel)")
                .textStyle(.stats)
                .foregroundStyle(Ink.quaternary)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(isLatest ? Surface.card : Surface.cardQuiet)
    }
}
