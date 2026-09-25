//
//  SavedListViewModel.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import Observation

@MainActor
protocol SavedListViewModeling: Observable, AnyObject {
    var saved: [MatchProfile] { get }
    var errorMessage: String? { get }

    func reload()
    func toggleSave(for profile: MatchProfile)
    func setDecision(_ decision: MatchDecision, for profile: MatchProfile)
    func dismissError()
}

@Observable
final class SavedListViewModel: SavedListViewModeling {
    private(set) var saved: [MatchProfile] = []
    var errorMessage: String?

    private let repository: ProfileRepository

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func reload() {
        do {
            saved = try repository.savedProfiles()
        } catch {
            errorMessage = AppError.map(error).errorDescription
        }
    }

    func toggleSave(for profile: MatchProfile) {
        do {
            try repository.setSaved(!profile.isSaved, for: profile)
            reload()
        } catch {
            errorMessage = AppError.map(error).errorDescription
        }
    }

    func setDecision(_ decision: MatchDecision, for profile: MatchProfile) {
        do {
            try repository.setDecision(decision, for: profile)
            reload()
        } catch {
            errorMessage = AppError.map(error).errorDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
