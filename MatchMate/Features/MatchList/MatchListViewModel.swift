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
@MainActor
@Observable
final class MatchListViewModel {
    // MARK: - Published state (read by the View)

    private(set) var profiles: [MatchProfile] = []
    private(set) var isLoadingInitial = false
    private(set) var isLoadingNextPage = false
    private(set) var isRefreshing = false
    private(set) var canLoadMore = true

    /// Non-nil when there's something worth telling the user about. The View
    /// shows this as a dismissible banner; cached content stays visible.
    var errorMessage: String?

    // MARK: - Dependencies

    private let repository: ProfileRepository
    private let networkMonitor: NetworkMonitoring
    private let pageSize: Int

    private var currentPage = 0

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
        guard profiles.isEmpty else { return }
        loadFromCache()
        await loadFirstPage()
    }

    /// Loads the cached profiles synchronously so the UI is never blank while the
    /// network request is in flight (offline-first).
    func loadFromCache() {
        do {
            profiles = try repository.cachedProfiles()
        } catch {
            errorMessage = AppError.map(error).errorDescription
        }
    }

    /// Fetches page 1. If offline, falls back to whatever is cached.
    func loadFirstPage() async {
        guard networkMonitor.isConnected else {
            if profiles.isEmpty {
                errorMessage = AppError.offline.errorDescription
            }
            return
        }

        isLoadingInitial = profiles.isEmpty
        defer { isLoadingInitial = false }

        do {
            let merged = try await repository.fetchAndStore(page: 1, pageSize: pageSize)
            profiles = merged
            currentPage = 1
            canLoadMore = true
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    /// Pull-to-refresh: re-fetch page 1 and reset pagination.
    func refresh() async {
        guard networkMonitor.isConnected else {
            errorMessage = AppError.offline.errorDescription
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        await loadFirstPage()
    }

    /// Prefetch trigger: call as each row appears. Loads the next page when the
    /// user nears the bottom.
    func loadNextPageIfNeeded(currentItem: MatchProfile) async {
        guard let index = profiles.firstIndex(where: { $0.id == currentItem.id }) else { return }
        let thresholdIndex = profiles.count - prefetchThreshold
        guard index >= thresholdIndex else { return }
        await loadNextPage()
    }

    /// Fetches the next page. No-ops while a page is already loading, when there's
    /// nothing more to load, or when offline.
    func loadNextPage() async {
        guard !isLoadingNextPage, !isLoadingInitial, canLoadMore else { return }
        guard networkMonitor.isConnected else { return }

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        let nextPage = currentPage + 1
        let previousCount = profiles.count

        do {
            let merged = try await repository.fetchAndStore(page: nextPage, pageSize: pageSize)
            profiles = merged
            currentPage = nextPage
            // If the page brought nothing new, stop paginating.
            canLoadMore = merged.count > previousCount
            errorMessage = nil
        } catch {
            handle(error)
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
            errorMessage = AppError.map(error).errorDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Helpers

    private func handle(_ error: Error) {
        let appError = AppError.map(error)
        // Offline is not "an error" if we still have cached content to show.
        if case .offline = appError, !profiles.isEmpty {
            errorMessage = nil
        } else {
            errorMessage = appError.errorDescription
        }
    }
}
