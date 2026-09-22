//
//  MatchListViewModeling.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import Observation

/// Abstraction the match-list screen depends on, instead of the concrete
/// `MatchListViewModel`. It refines `Observable` so SwiftUI observation keeps
/// working when a view is made generic over it, and lets tests/previews inject a
/// stub view model.
@MainActor
protocol MatchListViewModeling: Observable, AnyObject {
    /// The single source of truth for what the screen renders.
    var state: MatchListState { get }
    /// Convenience projections off `state`.
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
