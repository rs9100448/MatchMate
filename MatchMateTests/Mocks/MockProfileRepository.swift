//
//  MockProfileRepository.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
@testable import MatchMate

@MainActor
final class MockProfileRepository: ProfileRepository {
    var cached: [MatchProfile] = []
    var fetchError: Error?
    var setDecisionError: Error?

    func cachedProfiles() throws -> [MatchProfile] {
        if let fetchError { throw fetchError }
        return cached
    }

    @discardableResult
    func fetchAndStore(page: Int, pageSize: Int) async throws -> [MatchProfile] {
        if let fetchError { throw fetchError }
        return cached
    }

    func setDecision(_ decision: MatchDecision, for profile: MatchProfile) throws {
        if let setDecisionError { throw setDecisionError }
        profile.decision = decision
    }
}
