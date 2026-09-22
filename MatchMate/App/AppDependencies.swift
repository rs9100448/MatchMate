//
//  AppDependencies.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import SwiftData
import Observation


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

    func makeMatchListViewModel() -> some MatchListViewModeling {
        MatchListViewModel(repository: repository, networkMonitor: networkMonitor)
    }

    func makeMatchDetailViewModel(for profile: MatchProfile) -> some MatchDetailViewModeling {
        MatchDetailViewModel(profile: profile, repository: repository)
    }
}
