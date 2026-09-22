//
//  MatchListViewModelTests.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Testing
import Foundation
@testable import MatchMate

@MainActor
struct MatchListViewModelTests {

    // MARK: - Loading & pagination

    @Test("First page loads and populates profiles")
    func loadsFirstPage() async {
        let env = TestEnvironment(pageSize: 10)

        await env.listViewModel.loadFirstPage()

        #expect(env.listViewModel.profiles.count == 10)
        #expect(env.api.requestedPages == [1])
        #expect(env.listViewModel.errorMessage == nil)
    }

    @Test("Next page appends more profiles and keeps paging order")
    func paginationAppends() async {
        let env = TestEnvironment(pageSize: 10)

        await env.listViewModel.loadFirstPage()
        await env.listViewModel.loadNextPage()

        #expect(env.listViewModel.profiles.count == 20)
        #expect(env.api.requestedPages == [1, 2])
        // Order preserved: page-1 users first, then page-2 users.
        #expect(env.listViewModel.profiles.first?.id == "user-1-0")
        #expect(env.listViewModel.profiles.last?.id == "user-2-9")
    }

    @Test("Prefetch triggers next page only when nearing the end")
    func prefetchTriggersNearEnd() async {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()

        // An early item must not trigger a fetch.
        await env.listViewModel.loadNextPageIfNeeded(currentItem: env.listViewModel.profiles[0])
        #expect(env.api.requestedPages == [1])

        // A near-bottom item should.
        let nearEnd = env.listViewModel.profiles[8]
        await env.listViewModel.loadNextPageIfNeeded(currentItem: nearEnd)
        #expect(env.api.requestedPages == [1, 2])
    }

    @Test("onAppear loads the first page, and is a no-op once past idle")
    func onAppearLoadsThenGuards() async {
        let env = TestEnvironment(pageSize: 10)

        await env.listViewModel.onAppear()
        #expect(env.listViewModel.profiles.count == 10)
        #expect(env.api.requestedPages == [1])

        // Second call is guarded by `case .idle` — no extra fetch.
        await env.listViewModel.onAppear()
        #expect(env.api.requestedPages == [1])
    }

    @Test("loadFromCache surfaces persisted profiles without touching the network")
    func loadFromCacheShowsCachedProfiles() async {
        // Seed the store through one view model…
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()

        // …then a fresh view model on the same store shows them via cache only.
        let cachedFirst = MatchListViewModel(
            repository: env.repository,
            networkMonitor: env.network,
            pageSize: 10
        )
        cachedFirst.loadFromCache()

        #expect(cachedFirst.profiles.count == 10)
        #expect(cachedFirst.errorMessage == nil)
    }

    @Test("loadNextPage stops paging once a page adds nothing new")
    func paginationStopsWhenExhausted() async {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage() // page 1 → ids user-1-0…user-1-9

        // Page 2 returns the SAME ids → upsert updates in place, count doesn't
        // grow → `canLoadMore` becomes false.
        env.api.stubbedPages[2] = (0..<10).map { MockProfileAPI.makeUser(id: "user-1-\($0)") }
        await env.listViewModel.loadNextPage()
        #expect(env.listViewModel.profiles.count == 10)
        #expect(env.api.requestedPages == [1, 2])

        // Paging is now exhausted — a further attempt doesn't hit the network.
        await env.listViewModel.loadNextPage()
        #expect(env.api.requestedPages == [1, 2])
    }

    @Test("Pagination continues after a pull-to-refresh (does not stall)")
    func paginationContinuesAfterRefresh() async {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()
        await env.listViewModel.loadNextPage()
        await env.listViewModel.loadNextPage()
        #expect(env.listViewModel.profiles.count == 30)

        await env.listViewModel.refresh()
        #expect(env.listViewModel.profiles.count == 30)

        await env.listViewModel.loadNextPage()
        #expect(env.listViewModel.profiles.count == 40)
        #expect(env.api.requestedPages == [1, 2, 3, 1, 4])
    }

    @Test("loadNextPage does nothing while offline")
    func paginationNoOpOffline() async {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()
        env.network.isConnected = false

        await env.listViewModel.loadNextPage()

        #expect(env.api.requestedPages == [1]) // page 2 never requested
        #expect(env.listViewModel.profiles.count == 10)
    }

    @Test("Concurrent loadNextPage calls fetch the next page only once")
    func paginationCoalescesConcurrent() async {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()

        // The first call flips state to `.paginating` before suspending; the
        // second sees that and no-ops via the `!state.isPaginating` guard.
        async let first: Void = env.listViewModel.loadNextPage()
        async let second: Void = env.listViewModel.loadNextPage()
        _ = await (first, second)

        #expect(env.api.requestedPages == [1, 2]) // page 2 requested exactly once
        #expect(env.listViewModel.profiles.count == 20)
    }

    // MARK: - Decisions & persistence

    @Test("Accepting a profile persists and survives a reload from the store")
    func acceptPersists() async throws {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()

        let target = try #require(env.listViewModel.profiles.first)
        env.listViewModel.setDecision(.accepted, for: target)

        #expect(target.decision == .accepted)

        // Reload straight from the repository (simulates relaunch).
        let reloaded = try env.repository.cachedProfiles()
        let reloadedTarget = try #require(reloaded.first { $0.id == target.id })
        #expect(reloadedTarget.decision == .accepted)
    }

    @Test("Re-fetching a page preserves an existing decision (upsert never clobbers status)")
    func upsertPreservesDecision() async throws {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()

        let target = try #require(env.listViewModel.profiles.first)
        env.listViewModel.setDecision(.declined, for: target)

        // Pull-to-refresh re-fetches page 1 with the same seeded ids.
        await env.listViewModel.refresh()

        let refreshed = try #require(env.listViewModel.profiles.first { $0.id == target.id })
        #expect(refreshed.decision == .declined)
        #expect(env.listViewModel.profiles.count == 10) // no duplicates created
    }

    @Test("List and detail share one source of truth")
    func listAndDetailStayInSync() async throws {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()

        let profile = try #require(env.listViewModel.profiles.first)
        let detailVM = env.makeDetailViewModel(for: profile)

        // Decision taken on the *detail* screen…
        detailVM.setDecision(.accepted)

        // …is immediately visible through the *list* view model's object.
        let sameProfileInList = try #require(env.listViewModel.profiles.first { $0.id == profile.id })
        #expect(sameProfileInList.decision == .accepted)
        #expect(detailVM.decision == .accepted)
    }

    // MARK: - Offline & errors

    @Test("Offline with empty cache surfaces an offline message")
    func offlineEmptyCacheShowsMessage() async {
        let env = TestEnvironment(isConnected: false, pageSize: 10)

        await env.listViewModel.loadFirstPage()

        #expect(env.listViewModel.profiles.isEmpty)
        #expect(env.listViewModel.errorMessage == AppError.offline.errorDescription)
        #expect(env.api.requestedPages.isEmpty) // never hit the network
    }

    @Test("Offline still shows cached profiles without an error")
    func offlineShowsCache() async throws {
        // Seed the cache while "online", then go offline.
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()
        env.network.isConnected = false

        await env.listViewModel.loadFirstPage()

        #expect(env.listViewModel.profiles.count == 10)
        #expect(env.listViewModel.errorMessage == nil)
    }

    @Test("Accept/Decline works while offline")
    func decisionWorksOffline() async throws {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()
        env.network.isConnected = false

        let target = try #require(env.listViewModel.profiles.first)
        env.listViewModel.setDecision(.accepted, for: target)

        let reloaded = try env.repository.cachedProfiles()
        #expect(reloaded.first { $0.id == target.id }?.decision == .accepted)
    }

    @Test("A failing API surfaces an error message")
    func apiErrorSurfaces() async {
        let env = TestEnvironment(pageSize: 10)
        env.api.errorToThrow = AppError.requestFailed(status: 500)

        await env.listViewModel.loadFirstPage()

        #expect(env.listViewModel.profiles.isEmpty)
        #expect(env.listViewModel.errorMessage == AppError.requestFailed(status: 500).errorDescription)
    }

    @Test("Dismissing the error clears it")
    func dismissError() async {
        let env = TestEnvironment(pageSize: 10)
        env.api.errorToThrow = AppError.requestFailed(status: 500)
        await env.listViewModel.loadFirstPage()
        #expect(env.listViewModel.errorMessage != nil)

        env.listViewModel.dismissError()
        #expect(env.listViewModel.errorMessage == nil)
    }
}
