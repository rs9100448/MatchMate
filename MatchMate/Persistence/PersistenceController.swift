import Foundation
import SwiftData

/// Builds the app's `ModelContainer`.
///
/// Centralizing container creation keeps the schema in one place and gives tests
/// an easy `inMemory` variant that never touches disk.
enum PersistenceController {
    static let schema = Schema([MatchProfile.self])

    /// Persistent, on-disk store used by the running app.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A failure here means the on-disk store is corrupt or incompatible.
            // In a shipping app we'd attempt a migration/rebuild; for this
            // assignment a clear crash beats silently losing user data.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
