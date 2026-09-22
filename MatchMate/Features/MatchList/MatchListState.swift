//
//  MatchListState.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation

enum MatchListState: Equatable {
    case idle
    case loading
    case loaded([MatchProfile])
    case paginating([MatchProfile])
    case empty
    case failed(message: String, cached: [MatchProfile])
    var profiles: [MatchProfile] {
        switch self {
        case let .loaded(profiles), let .paginating(profiles), let .failed(_, profiles):
            return profiles
        case .idle, .loading, .empty:
            return []
        }
    }

    var errorMessage: String? {
        if case let .failed(message, _) = self { return message }
        return nil
    }

    var isLoadingInitial: Bool {
        if case .loading = self { return true }
        return false
    }

    var isPaginating: Bool {
        if case .paginating = self { return true }
        return false
    }

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}
