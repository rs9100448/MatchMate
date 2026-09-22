//
//  MatchDetailViewModelTests.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Testing
import Foundation
@testable import MatchMate

@MainActor
struct MatchDetailViewModelTests {

    private func makeProfile(id: String = "detail-1") -> MatchProfile {
        MockProfileAPI.makeUser(id: id).asDomain(sortIndex: 0)
    }

    // MARK: - decision (computed)
    @Test("decision reflects the underlying profile")
    func decisionReflectsProfile() {
        let profile = makeProfile()
        let viewModel = MatchDetailViewModel(profile: profile, repository: MockProfileRepository())

        #expect(viewModel.decision == .pending)

        profile.decision = .accepted
        #expect(viewModel.decision == .accepted)
    }

    // MARK: - setDecision (happy paths, real repository)
    @Test("Accepting writes through the repository and survives a reload")
    func acceptPersists() async throws {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()
        let profile = try #require(env.listViewModel.profiles.first)

        let detailVM = env.makeDetailViewModel(for: profile)
        detailVM.setDecision(.accepted)

        #expect(detailVM.decision == .accepted)
        #expect(detailVM.errorMessage == nil)

        // Reload straight from the store (simulates relaunch).
        let reloaded = try env.repository.cachedProfiles()
        #expect(reloaded.first { $0.id == profile.id }?.decision == .accepted)
    }

    @Test("Declining is recorded and persisted")
    func declinePersists() async throws {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()
        let profile = try #require(env.listViewModel.profiles.first)

        let detailVM = env.makeDetailViewModel(for: profile)
        detailVM.setDecision(.declined)

        #expect(detailVM.decision == .declined)
        let reloaded = try env.repository.cachedProfiles()
        #expect(reloaded.first { $0.id == profile.id }?.decision == .declined)
    }

    @Test("The data layer accepts any decision transition")
    func anyTransitionAllowed() async throws {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()
        let profile = try #require(env.listViewModel.profiles.first)
        let detailVM = env.makeDetailViewModel(for: profile)

        detailVM.setDecision(.accepted)
        #expect(detailVM.decision == .accepted)

        // The UI keeps a decision final, but the model layer allows reverting.
        detailVM.setDecision(.pending)
        #expect(detailVM.decision == .pending)

        let reloaded = try env.repository.cachedProfiles()
        #expect(reloaded.first { $0.id == profile.id }?.decision == .pending)
    }

    // MARK: - setDecision (error path, mock repository)
    @Test("A repository failure surfaces an error and leaves the decision unchanged")
    func setDecisionSurfacesError() {
        let profile = makeProfile()
        let repository = MockProfileRepository()
        repository.setDecisionError = AppError.persistence("write failed")
        let viewModel = MatchDetailViewModel(profile: profile, repository: repository)

        viewModel.setDecision(.accepted)

        #expect(viewModel.errorMessage == AppError.persistence("write failed").errorDescription)
        #expect(viewModel.decision == .pending) // the failed write didn't take
    }

    @Test("Dismissing the error clears it")
    func dismissClearsError() {
        let profile = makeProfile()
        let repository = MockProfileRepository()
        repository.setDecisionError = AppError.persistence("write failed")
        let viewModel = MatchDetailViewModel(profile: profile, repository: repository)

        viewModel.setDecision(.accepted)
        #expect(viewModel.errorMessage != nil)

        viewModel.dismissError()
        #expect(viewModel.errorMessage == nil)
    }
}
