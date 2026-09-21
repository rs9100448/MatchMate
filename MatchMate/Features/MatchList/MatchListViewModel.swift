//
//  MatchListViewModel.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import Observation

/// Drives the match list: offline-first loading, real pagination, decisions, and
/// error surfacing. Deliberately UI-free so it can be unit-tested in isolation.
///
/// All display state is funneled through a single `MatchListState` value, so the
/// screen is a genuine state machine rather than a bag of booleans.
@MainActor
@Observable
final class MatchListViewModel {
    // MARK: - State

    /// The single source of truth for what the screen shows. Only the ViewModel
    /// transitions it; the View only reads it.
    private(set) var state: MatchListState = .idle

    // Derived, read-only conveniences (used by the View and tests).
    var profiles: [MatchProfile] { state.profiles }
    var errorMessage: String? { state.errorMessage }

    // MARK: - Dependencies

    private let repository: ProfileRepository
    private let networkMonitor: NetworkMonitoring
    private let pageSize: Int

    // Pagination bookkeeping (not display state).
    private var currentPage = 0
    private var canLoadMore = true

    /// How close to the end of the list we get before prefetching the next page.
    private let prefetchThreshold = 3

    init(
        repository: ProfileRepository,
        networkMonitor: NetworkMonitoring,
        pageSize: Int = 10
    ) {
        self.repository = repository
        self.networkMonitor = networkMonitor
        self.pageSize = pageSize
    }

    // MARK: - Loading

    /// Called when the list first appears. Shows cache instantly, then refreshes
    /// page 1 from the network when possible.
    func onAppear() async {
        guard case .idle = state else { return }
        loadFromCache()
        await loadFirstPage()
    }

    /// Loads cached profiles so the UI is never blank while the network request is
    /// in flight (offline-first).
    func loadFromCache() {
        do {
            let cached = try repository.cachedProfiles()
            if !cached.isEmpty {
                state = .loaded(cached)
            }
        } catch {
            transitionToFailure(error)
        }
    }

    /// Fetches page 1. If offline, falls back to whatever is cached.
    func loadFirstPage() async {
        let cached = state.profiles

        guard networkMonitor.isConnected else {
            if cached.isEmpty {
                state = .failed(message: AppError.offline.errorDescription ?? "", cached: [])
            }
            // With cached content, staying on `.loaded` + the offline banner is the
            // right UX — being offline isn't an error when we have data to show.
            return
        }

        if cached.isEmpty {
            state = .loading
        }

        do {
            let merged = try await repository.fetchAndStore(page: 1, pageSize: pageSize)
            currentPage = 1
            canLoadMore = true
            state = merged.isEmpty ? .empty : .loaded(merged)
        } catch {
            transitionToFailure(error)
        }
    }

    /// Pull-to-refresh: re-fetch page 1 and reset pagination.
    func refresh() async {
        guard networkMonitor.isConnected else {
            if state.profiles.isEmpty {
                state = .failed(message: AppError.offline.errorDescription ?? "", cached: [])
            }
            return
        }
        await loadFirstPage()
    }

    /// Prefetch trigger: call as each row appears. Loads the next page when the
    /// user nears the bottom.
    func loadNextPageIfNeeded(currentItem: MatchProfile) async {
        let current = state.profiles
        guard let index = current.firstIndex(where: { $0.id == currentItem.id }) else { return }
        guard index >= current.count - prefetchThreshold else { return }
        await loadNextPage()
    }

    /// Fetches the next page. No-ops while a page is already loading, when there's
    /// nothing more to load, or when offline.
    func loadNextPage() async {
        guard !state.isPaginating, !state.isLoadingInitial, canLoadMore else { return }
        guard networkMonitor.isConnected else { return }

        let current = state.profiles
        guard !current.isEmpty else { return }

        state = .paginating(current)
        let previousCount = current.count
        let nextPage = currentPage + 1

        do {
            let merged = try await repository.fetchAndStore(page: nextPage, pageSize: pageSize)
            currentPage = nextPage
            // If the page brought nothing new, stop paginating.
            canLoadMore = merged.count > previousCount
            state = merged.isEmpty ? .empty : .loaded(merged)
        } catch {
            transitionToFailure(error)
        }
    }

    // MARK: - Decisions

    /// Records Accept/Decline. The change is written to the DB and, because the
    /// same `@Model` object is shown here and on the detail screen, both update
    /// immediately with no manual refresh.
    func setDecision(_ decision: MatchDecision, for profile: MatchProfile) {
        do {
            try repository.setDecision(decision, for: profile)
        } catch {
            transitionToFailure(error)
        }
    }

    /// Clears an error, returning to the best non-error state we can.
    func dismissError() {
        guard case let .failed(_, cached) = state else { return }
        state = cached.isEmpty ? .empty : .loaded(cached)
    }

    // MARK: - Transitions

    /// Maps a thrown error onto the state machine, preserving any content that was
    /// already on screen so failures never blank the list.
    private func transitionToFailure(_ error: Error) {
        let appError = AppError.map(error)
        let cached = state.profiles

        // Offline with content already shown is not an error — keep the content.
        if case .offline = appError, !cached.isEmpty {
            state = .loaded(cached)
        } else {
            state = .failed(message: appError.errorDescription ?? "", cached: cached)
        }
    }
}
