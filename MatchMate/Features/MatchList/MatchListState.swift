//
//  MatchListState.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation

/// Explicit, exhaustive UI state for the match list.
///
/// Replaces a spread of ad-hoc booleans (`isLoadingInitial`, `isLoadingNextPage`,
/// `errorMessage`, …) with one value that can only ever be in a single, legal
/// state. The View switches over it; the ViewModel is the only thing that
/// transitions it. This makes impossible states (e.g. "loading AND showing an
/// error AND empty") unrepresentable.
enum MatchListState: Equatable {
    /// Nothing has happened yet.
    case idle
    /// First load in flight with no content to show underneath.
    case loading
    /// Content is on screen and settled.
    case loaded([MatchProfile])
    /// Content is on screen and the next page is being fetched.
    case paginating([MatchProfile])
    /// A load finished successfully but there is nothing to show.
    case empty
    /// A load failed. `cached` carries whatever we can still show behind the
    /// error (empty ⇒ full-screen error; non-empty ⇒ inline banner over content).
    case failed(message: String, cached: [MatchProfile])

    /// The profiles this state should render, regardless of phase.
    var profiles: [MatchProfile] {
        switch self {
        case let .loaded(profiles), let .paginating(profiles), let .failed(_, profiles):
            return profiles
        case .idle, .loading, .empty:
            return []
        }
    }

    /// The user-facing error message, if any.
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
