import SwiftData
import SwiftUI

@main
struct ConteurApp: App {
    /// Local only for now. The models already satisfy CloudKit's constraints, so
    /// enabling sync is a matter of adding an iCloud container to the entitlement and
    /// passing `cloudKitDatabase: .automatic` here.
    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: StoredRetelling.self)
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
