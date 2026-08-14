import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \StoredRetelling.recordedAt, order: .reverse)
    private var retellings: [StoredRetelling]

    var body: some View {
        NavigationStack {
            List {
                if retellings.isEmpty {
                    ContentUnavailableView(
                        "Nothing yet",
                        systemImage: "waveform",
                        description: Text("Your retellings will collect here.")
                    )
                } else {
                    ForEach(retellings) { retelling in
                        NavigationLink {
                            RetellingDetailView(retelling: retelling)
                        } label: {
                            row(for: retelling)
                        }
                    }
                }
            }
            .navigationTitle("Retellings")
        }
    }

    private func row(for retelling: StoredRetelling) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(retelling.recordedAt, format: .dateTime.day().month().hour().minute())
                    .font(.subheadline)
                if retelling.attempt > 1 {
                    Text("second telling")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let focus = retelling.focusDimension {
                    Text(focus.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let note = retelling.note {
                Text(note)
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }

            Text("\(retelling.wordCount) words · \(retelling.duration.secondsLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
