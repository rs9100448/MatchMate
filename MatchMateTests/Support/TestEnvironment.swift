import Foundation
import SwiftData
@testable import MatchMate

/// Builds a fully wired, in-memory system under test. Using the *real*
/// `SwiftDataProfileRepository` against an in-memory store means the tests
/// exercise the actual persistence + upsert logic, not a fake of it.
@MainActor
struct TestEnvironment {
    let container: ModelContainer
    let api: MockProfileAPI
    let network: MockNetworkMonitor
    let repository: SwiftDataProfileRepository
    let listViewModel: MatchListViewModel

    init(isConnected: Bool = true, pageSize: Int = 10) {
        self.container = PersistenceController.makeContainer(inMemory: true)
        self.api = MockProfileAPI()
        self.network = MockNetworkMonitor(isConnected: isConnected)
        self.repository = SwiftDataProfileRepository(context: container.mainContext, api: api)
        self.listViewModel = MatchListViewModel(
            repository: repository,
            networkMonitor: network,
            pageSize: pageSize
        )
    }

    func makeDetailViewModel(for profile: MatchProfile) -> MatchDetailViewModel {
        MatchDetailViewModel(profile: profile, repository: repository)
    }
}
