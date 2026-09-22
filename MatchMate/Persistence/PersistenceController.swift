//
//  PersistenceController.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([MatchProfile.self])

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

            deleteStore(at: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }
    }

    private static func deleteStore(at url: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            try? fileManager.removeItem(at: file)
        }
    }
}
