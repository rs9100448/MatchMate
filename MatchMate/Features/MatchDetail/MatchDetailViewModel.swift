//
//  MatchDetailViewModel.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import Observation

@MainActor
protocol MatchDetailViewModeling: Observable, AnyObject {
    var profile: MatchProfile { get }
    var decision: MatchDecision { get }
    var errorMessage: String? { get }
    func setDecision(_ decision: MatchDecision)
    func dismissError()
}

final class MatchDetailViewModel: MatchDetailViewModeling {
    let profile: MatchProfile
    var errorMessage: String?

    private let repository: ProfileRepository

    init(profile: MatchProfile, repository: ProfileRepository) {
        self.profile = profile
        self.repository = repository
    }

    var decision: MatchDecision { profile.decision }

    func setDecision(_ decision: MatchDecision) {
        do {
            try repository.setDecision(decision, for: profile)
        } catch {
            errorMessage = AppError.map(error).errorDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
