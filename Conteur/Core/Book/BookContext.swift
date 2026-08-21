import Foundation
import SwiftData

/// Loads and mutates book state. All reads are from SwiftData; nothing leaves the
/// device, and every mutation is a single atomic save.
protocol BookContext {
    func books() throws -> [BookSession]
    func book(with id: UUID) throws -> BookSession?
    func createBook(title: String, shape: StoryShape) throws -> BookSession
    func append(events: [BookEvent], to book: BookSession) throws
    func update(registry: [EntityRecord], in book: BookSession) throws

    func events(for book: BookSession) throws -> [BookEvent]
    func events(for book: BookSession, kind: EventKind) throws -> [BookEvent]
    func events(for book: BookSession, subject: String) throws -> [BookEvent]
    func events(for book: BookSession, since session: Int) throws -> [BookEvent]
}

struct BookContextError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
struct SwiftDataBookContext: BookContext {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func books() throws -> [BookSession] {
        let descriptor = FetchDescriptor<BookSession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func book(with id: UUID) throws -> BookSession? {
        return try books().first { $0.bookID == id }
    }

    func createBook(title: String, shape: StoryShape) throws -> BookSession {
        let book = BookSession(title: title, shape: shape)
        context.insert(book)
        try context.save()
        return book
    }

    func append(events: [BookEvent], to book: BookSession) throws {
        for event in events {
            event.book = book
            book.events.append(event)
        }
        book.lastSessionNumber += 1
        try context.save()
    }

    func update(registry: [EntityRecord], in book: BookSession) throws {
        book.entityRegistry = registry
        try context.save()
    }

    func events(for book: BookSession) throws -> [BookEvent] {
        book.events.sorted { $0.timestamp < $1.timestamp }
    }

    func events(for book: BookSession, kind: EventKind) throws -> [BookEvent] {
        book.events
            .filter { $0.kind == kind }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func events(for book: BookSession, subject: String) throws -> [BookEvent] {
        book.events
            .filter { $0.subject == subject }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func events(for book: BookSession, since session: Int) throws -> [BookEvent] {
        book.events
            .filter { $0.sessionNumber >= session }
            .sorted { $0.timestamp < $1.timestamp }
    }
}
