//
//  PersistenceController.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import SwiftData

/// Builds the app's `ModelContainer`.
///
/// Centralizing container creation keeps the schema in one place and gives tests
/// an easy `inMemory` variant that never touches disk.
enum PersistenceController {
    static let schema = Schema([MatchProfile.self])

    /// Persistent, on-disk store used by the running app.
    ///
    /// If the existing store can't be opened — because it's corrupt or its schema
    /// is incompatible (e.g. a model change that isn't a lightweight migration) —
    /// we recover by discarding it and starting fresh rather than crashing. The
    /// data here is API-backed and re-fetchable, so a reset is safe; the user's
    /// decisions are the only local-only state, and losing them on an unreadable
    /// store is far better than an unlaunchable app.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            guard !inMemory else {
                fatalError("Failed to create in-memory ModelContainer: \(error)")
            }

            // Recover: remove the unreadable store and rebuild it.
            deleteStore(at: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }
    }

    /// Removes the SQLite store and its write-ahead-log siblings.
    private static func deleteStore(at url: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            try? fileManager.removeItem(at: file)
        }
    }
}
