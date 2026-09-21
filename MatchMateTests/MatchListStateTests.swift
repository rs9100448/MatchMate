//
//  MatchListStateTests.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Testing
import Foundation
@testable import MatchMate

/// Focused on the state machine transitions themselves.
@MainActor
struct MatchListStateTests {

    @Test("Starts idle, then transitions to loaded")
    func idleToLoaded() async {
        let env = TestEnvironment(pageSize: 10)
        #expect(env.listViewModel.state == .idle)

        await env.listViewModel.loadFirstPage()

        if case let .loaded(profiles) = env.listViewModel.state {
            #expect(profiles.count == 10)
        } else {
            Issue.record("Expected .loaded, got \(env.listViewModel.state)")
        }
    }

    @Test("Offline with empty cache transitions to .failed")
    func offlineEmptyGoesToFailed() async {
        let env = TestEnvironment(isConnected: false, pageSize: 10)

        await env.listViewModel.loadFirstPage()

        guard case let .failed(message, cached) = env.listViewModel.state else {
            Issue.record("Expected .failed, got \(env.listViewModel.state)")
            return
        }
        #expect(cached.isEmpty)
        #expect(message == AppError.offline.errorDescription)
    }

    @Test("A failure that has cached content keeps that content in .failed")
    func failureKeepsContent() async throws {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage() // .loaded(10)

        // Now make the next call fail and force a refresh.
        env.api.errorToThrow = AppError.requestFailed(status: 503)
        await env.listViewModel.refresh()

        guard case let .failed(_, cached) = env.listViewModel.state else {
            Issue.record("Expected .failed, got \(env.listViewModel.state)")
            return
        }
        #expect(cached.count == 10) // content preserved behind the error
        #expect(env.listViewModel.profiles.count == 10)
    }

    @Test("Dismissing an error returns to .loaded when content exists")
    func dismissReturnsToLoaded() async {
        let env = TestEnvironment(pageSize: 10)
        await env.listViewModel.loadFirstPage()
        env.api.errorToThrow = AppError.requestFailed(status: 503)
        await env.listViewModel.refresh() // .failed(_, 10)

        env.listViewModel.dismissError()

        if case let .loaded(profiles) = env.listViewModel.state {
            #expect(profiles.count == 10)
        } else {
            Issue.record("Expected .loaded after dismiss, got \(env.listViewModel.state)")
        }
    }

    @Test("Successful load with no results transitions to .empty")
    func emptyResultsGoToEmpty() async {
        let env = TestEnvironment(pageSize: 10)
        env.api.stubbedPages = [1: []] // API returns zero users

        await env.listViewModel.loadFirstPage()

        #expect(env.listViewModel.state == .empty)
        #expect(env.listViewModel.profiles.isEmpty)
    }
}
