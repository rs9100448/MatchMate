//
//  MatchDetailViewModeling.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import Observation

/// Abstraction the detail screen depends on, instead of the concrete
/// `MatchDetailViewModel`. Refines `Observable` so observation survives making the
/// view generic over it.
@MainActor
protocol MatchDetailViewModeling: Observable, AnyObject {
    var profile: MatchProfile { get }
    var decision: MatchDecision { get }
    var errorMessage: String? { get }

    func setDecision(_ decision: MatchDecision)
    func dismissError()
}
