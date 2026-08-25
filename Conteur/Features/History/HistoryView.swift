import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \StoredRetelling.recordedAt, order: .reverse)
    private var retellings: [StoredRetelling]
    
    @State private var expandedId: PersistentIdentifier? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("Recents")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.gray)
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                    if retellings.isEmpty {
                        empty
                            .padding(.horizontal, 24)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(retellings) { retelling in
                                historyRow(retelling)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(hex: 0x0A1024))
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing yet")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text("Your retellings will collect here.")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.gray)
        }
    }

    private func historyRow(_ retelling: StoredRetelling) -> some View {
        let isExpanded = expandedId == retelling.id
        
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if expandedId == retelling.id {
                        expandedId = nil
                    } else {
                        expandedId = retelling.id
                    }
                }
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(retelling.storyTitle ?? "A story")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                            
                            let tellingText = retelling.attempt > 1 ? "Second Telling" : "First Telling"
                            Text(tellingText)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Capsule())
                        }
                        
                        Text(retelling.recordedAt.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isExpanded ? -180 : 0))
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded, let note = retelling.note {
                NavigationLink {
                    RetellingDetailView(retelling: retelling)
                } label: {
                    Text(note)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color.gray)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
            }
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
    }
}
