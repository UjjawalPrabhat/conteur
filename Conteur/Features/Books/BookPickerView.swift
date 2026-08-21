import SwiftData
import SwiftUI

struct BookPickerView: View {
    let books: [BookSession]
    let onSelect: (BookSession) -> Void
    let newBook: (String) -> Void
    let onDetail: (BookSession) -> Void

    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            List {
                if books.isEmpty {
                    ContentUnavailableView(
                        "No books yet",
                        systemImage: "book",
                        description: Text("Create a book to start retelling.")
                    )
                } else {
                    ForEach(books) { book in
                        Button {
                            onSelect(book)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(book.title)
                                    .font(.headline)
                                Text("Session \(book.lastSessionNumber) · \(book.entityRegistry.count) entities")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(book.startedAt, format: .dateTime.day().month().year())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Details") {
                                onDetail(book)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Books")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Book") {
                        createBook()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                TextField("Book title", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding()
            }
        }
    }

    private func createBook() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newBook(trimmed)
        newTitle = ""
    }
}
