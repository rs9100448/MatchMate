//
//  MappingAndDetailTests.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Testing
import Foundation
@testable import MatchMate

@MainActor
struct MappingAndDetailTests {

    @Test("API user maps into the domain model using login.uuid as id")
    func mapsUserToDomain() {
        let user = MockProfileAPI.makeUser(id: "abc-123", first: "Grace", last: "Hopper")

        let profile = user.asDomain(sortIndex: 5)

        #expect(profile.id == "abc-123")
        #expect(profile.fullName == "Grace Hopper")
        #expect(profile.sortIndex == 5)
        #expect(profile.decision == .pending)
        #expect(profile.largeImageURLString == user.picture.large)
    }

    // Detail view-model behavior lives in MatchDetailViewModelTests.

    @Test("URLError is normalized to the offline case")
    func mapsURLErrorToOffline() {
        let mapped = AppError.map(URLError(.notConnectedToInternet))
        #expect(mapped == .offline)
    }
}
