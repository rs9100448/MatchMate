import Foundation
import SwiftData
import Observation

/// Composition root: the single place where concrete implementations are wired
/// together. Views and ViewModels receive their dependencies from here, so
/// nothing constructs its own collaborators (which keeps everything injectable
/// and testable).
@MainActor
@Observable
final class AppDependencies {
    let container: ModelContainer
    let networkMonitor: NetworkMonitor
    let repository: ProfileRepository

    init(inMemory: Bool = false) {
        let container = PersistenceController.makeContainer(inMemory: inMemory)
        self.container = container
        self.networkMonitor = NetworkMonitor()
        self.repository = SwiftDataProfileRepository(
            context: container.mainContext,
            api: RandomUserAPI()
        )
    }

    /// Factory for the list screen's ViewModel.
    func makeMatchListViewModel() -> MatchListViewModel {
        MatchListViewModel(repository: repository, networkMonitor: networkMonitor)
    }

    /// Factory for the detail screen's ViewModel.
    func makeMatchDetailViewModel(for profile: MatchProfile) -> MatchDetailViewModel {
        MatchDetailViewModel(profile: profile, repository: repository)
    }
}
