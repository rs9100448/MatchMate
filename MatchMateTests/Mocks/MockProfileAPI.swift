//
//  MockProfileAPI.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
@testable import MatchMate

/// Deterministic stand-in for the real API. Generates stable, page-addressable
/// users so pagination and upsert behavior can be asserted precisely.
final class MockProfileAPI: ProfileAPI, @unchecked Sendable {
    /// If set, the next fetch throws this instead of returning users.
    var errorToThrow: Error?

    /// Overrides the generated users for a specific page when provided.
    var stubbedPages: [Int: [RandomUser]] = [:]

    /// Records every page that was requested, in order.
    private(set) var requestedPages: [Int] = []

    func fetchProfiles(page: Int, pageSize: Int) async throws -> [RandomUser] {
        requestedPages.append(page)

        if let errorToThrow {
            throw errorToThrow
        }

        if let stubbed = stubbedPages[page] {
            return stubbed
        }

        return (0..<pageSize).map { index in
            MockProfileAPI.makeUser(id: "user-\(page)-\(index)",
                                    first: "First\(page)\(index)",
                                    last: "Last\(page)\(index)")
        }
    }

    static func makeUser(id: String, first: String = "Ada", last: String = "Lovelace") -> RandomUser {
        RandomUser(
            gender: "female",
            name: .init(title: "Ms", first: first, last: last),
            location: .init(city: "London", state: "Greater London", country: "United Kingdom"),
            email: "\(first.lowercased())@example.com",
            login: .init(uuid: id),
            dob: .init(date: "1990-01-01T00:00:00.000Z", age: 30),
            registered: .init(date: "2015-06-01T12:00:00.000Z", age: 9),
            phone: "011-111-2222",
            cell: "077-333-4444",
            picture: .init(
                large: "https://randomuser.me/api/portraits/women/1.jpg",
                medium: "https://randomuser.me/api/portraits/med/women/1.jpg",
                thumbnail: "https://randomuser.me/api/portraits/thumb/women/1.jpg"
            ),
            nat: "GB"
        )
    }
}
