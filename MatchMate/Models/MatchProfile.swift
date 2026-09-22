//
//  MatchProfile.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import SwiftData

@Model
final class MatchProfile {
    @Attribute(.unique) var id: String

    var firstName: String
    var lastName: String
    var email: String
    var phone: String
    var cell: String
    var gender: String
    var age: Int
    var city: String
    var state: String
    var country: String
    var nationality: String
    var registeredDate: Date

    var mediumImageURLString: String
    var largeImageURLString: String

    var decisionRaw: String

    var sortIndex: Int

    var cachedAt: Date

    var decision: MatchDecision {
        get { MatchDecision(rawValue: decisionRaw) ?? .pending }
        set { decisionRaw = newValue.rawValue }
    }

    init(
        id: String,
        firstName: String,
        lastName: String,
        email: String,
        phone: String,
        cell: String,
        gender: String,
        age: Int,
        city: String,
        state: String,
        country: String,
        nationality: String,
        registeredDate: Date,
        mediumImageURLString: String,
        largeImageURLString: String,
        decision: MatchDecision = .pending,
        sortIndex: Int = 0,
        cachedAt: Date = .now
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.cell = cell
        self.gender = gender
        self.age = age
        self.city = city
        self.state = state
        self.country = country
        self.nationality = nationality
        self.registeredDate = registeredDate
        self.mediumImageURLString = mediumImageURLString
        self.largeImageURLString = largeImageURLString
        self.decisionRaw = decision.rawValue
        self.sortIndex = sortIndex
        self.cachedAt = cachedAt
    }
}

// MARK: - Derived, view-friendly helpers

extension MatchProfile {
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var location: String {
        [city, state, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Compact "City, Country" used on the list card.
    var cityCountry: String {
        [city, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var mediumImageURL: URL? { URL(string: mediumImageURLString) }
    var largeImageURL: URL? { URL(string: largeImageURLString) }
}
