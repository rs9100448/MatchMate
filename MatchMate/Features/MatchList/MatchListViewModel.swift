//
//  MatchListViewModel.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import Observation

@MainActor
protocol MatchListViewModeling: Observable, AnyObject {
    var state: MatchListState { get }
    var profiles: [MatchProfile] { get }
    var errorMessage: String? { get }

    func onAppear() async
    func loadFirstPage() async
    func refresh() async
    func loadNextPageIfNeeded(currentItem: MatchProfile) async
    func loadNextPage() async
    func setDecision(_ decision: MatchDecision, for profile: MatchProfile)
    func dismissError()
}

final class MatchListViewModel: MatchListViewModeling {
    // MARK: - State
    private(set) var state: MatchListState = .idle

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

        // Run the fetch in an unstructured task so it is NOT tied to the caller's
        // cancellation. The trigger comes from a list row's `.task`, which SwiftUI
        // cancels the moment that row scrolls off screen; without this, a quick
        // scroll would abort the in-flight page load. We still `await` it, so
        // callers (and tests) observe it through to completion.
        //
        // The task inherits this @MainActor context and does the state update
        // itself, returning `Void`. That keeps the non-Sendable `[MatchProfile]`
        // entirely inside the actor — nothing crosses the `.value` boundary, so
        // there's no Sendable warning (`PersistentModel` isn't Sendable).
        await Task {
            do {
                let merged = try await repository.fetchAndStore(page: nextPage, pageSize: pageSize)
                currentPage = nextPage
                // If the page brought nothing new, stop paginating.
                canLoadMore = merged.count > previousCount
                state = merged.isEmpty ? .empty : .loaded(merged)
            } catch {
                transitionToFailure(error)
            }
        }.value
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
