import Foundation
import SwiftData
import Testing

@testable import Conteur

@MainActor
struct BookPersistenceTests {
    @Test func aNewBookIsPersistedAndFetchedById() throws {
        let container = try ModelContainer(for: StoredRetelling.self, BookSession.self, BookEvent.self)
        let context = SwiftDataBookContext(context: container.mainContext)

        let book = try context.createBook(title: "Runtime Book", shape: .plotDriven)

        let fetched = try context.book(with: book.bookID)
        #expect(fetched != nil)
        #expect(fetched?.title == "Runtime Book")
        #expect(fetched?.shape == .plotDriven)
    }

    @Test func bookEventsAreAppendedAndAvailableAfterRefetch() throws {
        let container = try ModelContainer(for: StoredRetelling.self, BookSession.self, BookEvent.self)
        let context = SwiftDataBookContext(context: container.mainContext)
        let book = try context.createBook(title: "Event Book", shape: .thematic)

        let events = [
            BookEvent(
                sessionNumber: 1,
                timestamp: 0.0,
                kind: Conteur.EventKind.entityIntroduced,
                subject: "brother",
                detailText: "The brother was introduced."
            ),
            BookEvent(
                sessionNumber: 1,
                timestamp: 10.5,
                kind: Conteur.EventKind.stakesStated,
                subject: "stakes",
                detailText: "The stakes became clear."
            )
        ]

        try context.append(events: events, to: book)
        let refetched = try requireOptional(context.book(with: book.bookID))

        #expect(refetched.events.count == 2)
        #expect(refetched.lastSessionNumber == 1)

        let kinds = Set(refetched.events.map(\.kind))
        #expect(kinds == Set([Conteur.EventKind.entityIntroduced, Conteur.EventKind.stakesStated]))

        let brother = refetched.events.first { $0.subject == "brother" && $0.kind == Conteur.EventKind.entityIntroduced }
        #expect(brother?.detailText == "The brother was introduced.")
    }

    @Test func entityRegistrySurvivesARoundTrip() throws {
        let container = try ModelContainer(for: StoredRetelling.self, BookSession.self, BookEvent.self)
        let context = SwiftDataBookContext(context: container.mainContext)
        let book = try context.createBook(title: "Registry Book", shape: Conteur.StoryShape.episodic)

        let registry = [
            Conteur.EntityRecord(
                id: UUID(),
                name: "brother",
                introducedInSession: 1,
                firstAppearanceDescription: "First mention of brother.",
                lastMentionedSession: 1,
                mentionCount: 1,
                emotionalAssociations: []
            )
        ]

        try context.update(registry: registry, in: book)
        let refetched = try requireOptional(context.book(with: book.bookID))

        #expect(refetched.entityRegistry.count == 1)
        #expect(refetched.entityRegistry.first?.name == "brother")
        #expect(refetched.entityRegistry.first?.mentionCount == 1)
    }
}

private func requireOptional<T>(_ value: T?) -> T {
    guard let value else {
        Issue.record("Required value was nil")
        fatalError("Required value was nil")
    }
    return value
}
