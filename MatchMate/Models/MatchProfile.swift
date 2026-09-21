import Foundation
import SwiftData

/// The single source of truth for a match profile.
///
/// This is a SwiftData `@Model`, so instances are reference types that conform
/// to `Observable`. Because the *same* object is handed to both the list card
/// and the detail screen, mutating `decisionRaw` in one place is reflected in
/// the other automatically — this is how "list and detail never disagree"
/// without any manual refresh.
@Model
final class MatchProfile {
    /// Stable identity from the API's `login.uuid`. Used to de-duplicate across
    /// pages and to upsert on refresh without clobbering the saved decision.
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

    var thumbnailURLString: String
    var largeImageURLString: String

    /// Backing store for `decision`. Persisted as a `String` for schema stability.
    var decisionRaw: String

    /// Preserves the API's paging order so the list renders deterministically.
    var sortIndex: Int

    /// When this profile was first cached — useful for debugging / cache policy.
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
        thumbnailURLString: String,
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
        self.thumbnailURLString = thumbnailURLString
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

    var thumbnailURL: URL? { URL(string: thumbnailURLString) }
    var largeImageURL: URL? { URL(string: largeImageURLString) }
}
