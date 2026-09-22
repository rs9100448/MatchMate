//
//  MatchDetailViewModel.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import Observation

/// Drives the detail screen. It holds the *same* `MatchProfile` instance the list
/// shows, so decisions made here are reflected on the list card automatically
/// when the user navigates back — no reload, no notification plumbing.
@MainActor
@Observable
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
