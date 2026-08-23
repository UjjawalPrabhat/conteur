import SwiftData
import SwiftUI

@main
struct ConteurApp: App {
    /// Local only for now. The models already satisfy CloudKit's constraints, so
    /// enabling sync is a matter of adding an iCloud container to the entitlement and
    /// passing `cloudKitDatabase: .automatic` here.
    ///
    /// A store that will not open — a full disk, a file left corrupt by a crash — is not a
    /// reason to refuse to launch. History becomes unavailable, which the Progress tab already
    /// renders as an empty history, and the telling loop itself needs nothing from disk.
    private let container: ModelContainer = {
        if let onDisk = try? ModelContainer(for: StoredRetelling.self) { return onDisk }

        let temporary = ModelConfiguration(isStoredInMemoryOnly: true)
        if let inMemory = try? ModelContainer(for: StoredRetelling.self, configurations: temporary) {
            return inMemory
        }
        // Nowhere left to put a model container, on-disk or otherwise. Nothing in the app can
        // run without one, and there is no honest screen to show for it.
        fatalError("Could not open the retelling store, in memory or on disk")
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
