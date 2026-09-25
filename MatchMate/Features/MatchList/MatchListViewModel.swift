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
    func toggleSave(for profile: MatchProfile)
    func dismissError()
}

@Observable
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
            canLoadMore = true
            state = merged.isEmpty ? .empty : .loaded(merged)
        } catch {
            transitionToFailure(error)
        }
    }

    func refresh() async {
        guard networkMonitor.isConnected else {
            if state.profiles.isEmpty {
                state = .failed(message: AppError.offline.errorDescription ?? "", cached: [])
            }
            return
        }
        await loadFirstPage()
    }

    func loadNextPageIfNeeded(currentItem: MatchProfile) async {
        let current = state.profiles
        guard let index = current.firstIndex(where: { $0.id == currentItem.id }) else { return }
        guard index >= current.count - prefetchThreshold else { return }
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !state.isPaginating, !state.isLoadingInitial, canLoadMore else { return }
        guard networkMonitor.isConnected else { return }

        let current = state.profiles
        guard !current.isEmpty else { return }

        state = .paginating(current)
        let previousCount = current.count
        let nextPage = current.count / pageSize + 1

        await Task {
            do {
                let merged = try await repository.fetchAndStore(page: nextPage, pageSize: pageSize)
                // If the page brought nothing new, stop paginating.
                canLoadMore = merged.count > previousCount
                state = merged.isEmpty ? .empty : .loaded(merged)
            } catch {
                transitionToFailure(error)
            }
        }.value
    }

    // MARK: - Decisions
    func setDecision(_ decision: MatchDecision, for profile: MatchProfile) {
        do {
            try repository.setDecision(decision, for: profile)
        } catch {
            transitionToFailure(error)
        }
    }

    func toggleSave(for profile: MatchProfile) {
        do {
            try repository.setSaved(!profile.isSaved, for: profile)
        } catch {
            transitionToFailure(error)
        }
    }

    func dismissError() {
        guard case let .failed(_, cached) = state else { return }
        state = cached.isEmpty ? .empty : .loaded(cached)
    }

    // MARK: - Transitions
    private func transitionToFailure(_ error: Error) {
        let appError = AppError.map(error)
        let cached = state.profiles

        if case .offline = appError, !cached.isEmpty {
            state = .loaded(cached)
        } else {
            state = .failed(message: appError.errorDescription ?? "", cached: cached)
        }
    }
}
