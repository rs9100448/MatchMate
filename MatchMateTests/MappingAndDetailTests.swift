import Testing
import Foundation
@testable import MatchMate

@MainActor
struct MappingAndDetailTests {

    @Test("API user maps into the domain model using login.uuid as id")
    func mapsUserToDomain() {
        let user = MockProfileAPI.makeUser(id: "abc-123", first: "Grace", last: "Hopper")

        let profile = user.asDomain(sortIndex: 5)

        #expect(profile.id == "abc-123")
        #expect(profile.fullName == "Grace Hopper")
        #expect(profile.sortIndex == 5)
        #expect(profile.decision == .pending)
        #expect(profile.largeImageURLString == user.picture.large)
    }

    @Test("Detail view model writes decisions through the repository")
    func detailWritesDecision() async throws {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()
        let profile = try #require(env.listViewModel.profiles.first)

        let detailVM = env.makeDetailViewModel(for: profile)
        detailVM.setDecision(.declined)
        #expect(detailVM.decision == .declined)

        detailVM.setDecision(.pending) // undo
        #expect(detailVM.decision == .pending)

        let reloaded = try env.repository.cachedProfiles()
        #expect(reloaded.first { $0.id == profile.id }?.decision == .pending)
    }

    @Test("URLError is normalized to the offline case")
    func mapsURLErrorToOffline() {
        let mapped = AppError.map(URLError(.notConnectedToInternet))
        #expect(mapped == .offline)
    }
}
