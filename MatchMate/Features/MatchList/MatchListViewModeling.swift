//
//  MatchListViewModeling.swift
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
