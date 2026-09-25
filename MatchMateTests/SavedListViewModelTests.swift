//
//  SavedListViewModelTests.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Testing
import Foundation
@testable import MatchMate

@MainActor
struct SavedListViewModelTests {

    // MARK: - Helpers

    private func makeProfile(
        id: String,
        isSaved: Bool = false,
        savedAt: Date? = nil
    ) -> MatchProfile {
        let profile = MockProfileAPI.makeUser(id: id).asDomain(sortIndex: 0)
        profile.isSaved = isSaved
        profile.savedAt = savedAt
        return profile
    }

    // MARK: - reload

    @Test("reload surfaces saved profiles, most-recently-saved first")
    func reloadSurfacesSavedOrdered() {
        let now = Date()
        let mock = MockProfileRepository()
        mock.cached = [
            makeProfile(id: "old", isSaved: true, savedAt: now.addingTimeInterval(-300)),
            makeProfile(id: "new", isSaved: true, savedAt: now.addingTimeInterval(-100)),
            makeProfile(id: "mid", isSaved: true, savedAt: now.addingTimeInterval(-200)),
            makeProfile(id: "unsaved", isSaved: false, savedAt: nil)
        ]
        let vm = SavedListViewModel(repository: mock)

        vm.reload()

        #expect(vm.saved.map(\.id) == ["new", "mid", "old"])
    }

    // MARK: - toggleSave

    @Test("toggleSave adds an unsaved profile, then removes it on a second toggle")
    func toggleSaveAddsThenRemoves() {
        let profile = makeProfile(id: "a", isSaved: false)
        let mock = MockProfileRepository()
        mock.cached = [profile]
        let vm = SavedListViewModel(repository: mock)

        vm.toggleSave(for: profile)
        #expect(vm.saved.map(\.id) == ["a"])

        vm.toggleSave(for: profile)
        #expect(vm.saved.isEmpty)
    }

    // MARK: - Auto-remove on decision

    @Test("Accepting a saved profile removes it from the saved list")
    func acceptRemovesFromSaved() {
        let profile = makeProfile(id: "a", isSaved: true, savedAt: Date())
        let mock = MockProfileRepository()
        mock.cached = [profile]
        let vm = SavedListViewModel(repository: mock)
        vm.reload()
        #expect(vm.saved.map(\.id) == ["a"])

        vm.setDecision(.accepted, for: profile)

        #expect(vm.saved.isEmpty)
        #expect(profile.decision == .accepted)
    }

    // MARK: - Error handling

    @Test("A reload failure surfaces an error that can be dismissed")
    func errorSurfacesAndDismisses() {
        let mock = MockProfileRepository()
        mock.fetchError = AppError.persistence("boom")
        let vm = SavedListViewModel(repository: mock)

        vm.reload()
        #expect(vm.errorMessage != nil)

        vm.dismissError()
        #expect(vm.errorMessage == nil)
    }
}
