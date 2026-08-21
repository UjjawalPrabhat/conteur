import SwiftData
import SwiftUI

/// Owns the loop: tell it, hear how you told it, tell it again, see what changed.
///
/// Every telling ends on the feedback screen — a second one simply shows what changed at
/// the top of it. That keeps the loop open past two attempts, and means no telling can
/// ever end without feedback.
struct TellFlowView: View {
    private enum Stage: Equatable {
        case bookSelection
        case telling
        case feedback
    }

    @Environment(\.modelContext) private var context
    @State private var bookContext: SwiftDataBookContext?

    @State private var stage: Stage = .bookSelection
    @State private var group = UUID()
    @State private var attempt = 1
    @State private var previous: Assessment?
    @State private var current: Assessment?
    @State private var isTelling = false
    @State private var selectedBook: BookSession?
    @State private var availableBooks: [BookSession] = []
    @State private var mode: ChallengeMode = .standalone

    var body: some View {
        content
            // The tab bar is a distraction while somebody is mid-story, so it goes
            // away for the telling and comes back afterwards.
            .toolbar(isTelling ? .hidden : .automatic, for: .tabBar)
            .task { await loadBooks() }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .bookSelection:
            bookSelection

        case .telling:
            session

        case .feedback:
            if let current {
                FeedbackView(
                    assessment: current,
                    hasPrevious: previous != nil,
                    onRetell: { retell() },
                    onDone: { restart() }
                )
            }
        }
    }

    @State private var detailedBook: BookSession?

    @ViewBuilder
    private var bookSelection: some View {
        if selectedBook == nil {
            BookPickerView(
                books: availableBooks,
                onSelect: { book in
                    selectedBook = book
                    stage = .telling
                },
                newBook: { title in
                    guard let bookContext else { return }
                    if let book = try? bookContext.createBook(title: title, shape: .thematic) {
                        availableBooks.append(book)
                        selectedBook = book
                        stage = .telling
                    }
                },
                onDetail: { book in
                    detailedBook = book
                }
            )
            .sheet(item: $detailedBook) { book in
                BookDetailView(book: book)
            }
        } else {
            session
        }
    }

    private var session: some View {
        let store = SwiftDataRetellingStore(context: context)
        let challenge: String? = mode == .continuation ? previous?.feedback?.challenge : nil

        return SessionView(
            challenge: challenge,
            baseline: store.baseline(),
            history: previous?.focus.flatMap { store.lastBand(for: $0) },
            previous: previous?.diagnosis,
            readingProgress: previous?.readingProgress ?? .none,
            book: selectedBook,
            bookContext: bookContext,
            isTelling: $isTelling
        ) { assessment in
            try? store.save(assessment, attempt: attempt, group: group, isBenchmark: false)
            current = assessment
            stage = .feedback
        }
        // A fresh identity per attempt so the session screen starts clean rather than
        // reusing the previous attempt's view model.
        .id(attempt)
    }

    private func loadBooks() async {
        bookContext = SwiftDataBookContext(context: context)
        availableBooks = (try? bookContext?.books()) ?? []
    }

    private func retell() {
        previous = current
        current = nil
        attempt += 1
        mode = .continuation
        isTelling = false
        stage = .telling
    }

    private func restart() {
        previous = nil
        current = nil
        attempt = 1
        mode = .standalone
        group = UUID()
        isTelling = false
        stage = .bookSelection
        selectedBook = nil
    }
}
