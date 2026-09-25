//
//  ProfileRepositoryTests.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Testing
import Foundation
import SwiftData
@testable import MatchMate

@MainActor
struct ProfileRepositoryTests {

    // MARK: - Helpers

    // Held as a stored property so the in-memory ModelContainer stays alive for
    // the whole test (a fresh TestEnvironment is created per test instance).
    private let env = TestEnvironment()
    private var repo: SwiftDataProfileRepository { env.repository }
    private var context: ModelContext { env.container.mainContext }

    @discardableResult
    private func insert(
        id: String,
        sortIndex: Int = 0,
        isSaved: Bool = false,
        savedAt: Date? = nil
    ) -> MatchProfile {
        let profile = MockProfileAPI.makeUser(id: id).asDomain(sortIndex: sortIndex)
        profile.isSaved = isSaved
        profile.savedAt = savedAt
        context.insert(profile)
        return profile
    }

    // MARK: - setSaved

    @Test("setSaved(true) flags the profile and stamps savedAt; setSaved(false) clears both")
    func setSavedTogglesFlagAndTimestamp() throws {
        let profile = insert(id: "a")

        try repo.setSaved(true, for: profile)
        #expect(profile.isSaved == true)
        #expect(profile.savedAt != nil)

        try repo.setSaved(false, for: profile)
        #expect(profile.isSaved == false)
        #expect(profile.savedAt == nil)
    }

    // MARK: - Auto-remove on decision

    @Test("Accepting a saved profile clears its saved state")
    func acceptClearsSavedState() throws {
        let profile = insert(id: "a")
        try repo.setSaved(true, for: profile)

        try repo.setDecision(.accepted, for: profile)

        #expect(profile.decision == .accepted)
        #expect(profile.isSaved == false)
        #expect(profile.savedAt == nil)
    }

    @Test("Marking a saved profile pending leaves its saved state intact")
    func pendingKeepsSavedState() throws {
        let profile = insert(id: "a")
        try repo.setSaved(true, for: profile)

        try repo.setDecision(.pending, for: profile)

        #expect(profile.decision == .pending)
        #expect(profile.isSaved == true)
        #expect(profile.savedAt != nil)
    }

    // MARK: - savedProfiles fetch

    @Test("savedProfiles returns only saved profiles, most-recently-saved first")
    func savedProfilesAreFilteredAndOrdered() throws {
        let now = Date()
        // oldest → newest saved; one unsaved profile that must be excluded.
        insert(id: "old", sortIndex: 0, isSaved: true, savedAt: now.addingTimeInterval(-300))
        insert(id: "new", sortIndex: 1, isSaved: true, savedAt: now.addingTimeInterval(-100))
        insert(id: "mid", sortIndex: 2, isSaved: true, savedAt: now.addingTimeInterval(-200))
        insert(id: "unsaved", sortIndex: 3, isSaved: false, savedAt: nil)

        let saved = try repo.savedProfiles()

        #expect(saved.map(\.id) == ["new", "mid", "old"])
    }

    @Test("savedProfiles returns empty when nothing is saved")
    func savedProfilesEmptyWhenNoneSaved() throws {
        insert(id: "a", isSaved: false)

        #expect(try repo.savedProfiles().isEmpty)
    }
}
