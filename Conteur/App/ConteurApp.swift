import SwiftData
import SwiftUI

@main
struct ConteurApp: App {
    /// Local only for now. The models already satisfy CloudKit's constraints, so
    /// enabling sync is a matter of adding an iCloud container to the entitlement and
    /// passing `cloudKitDatabase: .automatic` here.
    private let container: ModelContainer = {
        do {
            let schema = Schema([StoredRetelling.self, BookSession.self, BookEvent.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not open the retelling store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
