import Foundation

/// Wire model for `https://randomuser.me/api`.
///
/// These types deliberately mirror the JSON shape and are kept separate from the
/// `MatchProfile` persistence model. Mapping happens in one place (`asDomain`)
/// so the rest of the app never depends on the API's structure.
struct RandomUserResponse: Decodable, Sendable {
    let results: [RandomUser]
    let info: Info

    struct Info: Decodable, Sendable {
        let seed: String
        let results: Int
        let page: Int
    }
}

struct RandomUser: Decodable, Sendable {
    let gender: String
    let name: Name
    let location: Location
    let email: String
    let login: Login
    let dob: DOB
    let registered: Registered
    let phone: String
    let cell: String
    let picture: Picture
    let nat: String

    struct Name: Decodable, Sendable {
        let title: String
        let first: String
        let last: String
    }

    struct Location: Decodable, Sendable {
        let city: String
        let state: String
        let country: String
    }

    struct Login: Decodable, Sendable {
        let uuid: String
    }

    struct DOB: Decodable, Sendable {
        let date: String
        let age: Int
    }

    struct Registered: Decodable, Sendable {
        let date: String
        let age: Int
    }

    struct Picture: Decodable, Sendable {
        let large: String
        let medium: String
        let thumbnail: String
    }
}

// MARK: - Mapping to the domain model

extension RandomUser {
    /// Maps a decoded API user into a fresh `MatchProfile`.
    ///
    /// - Parameter sortIndex: Global paging order, so the list stays stable.
    /// - Note: A new profile always starts as `.pending`. The repository is
    ///   responsible for preserving an existing decision on upsert.
    func asDomain(sortIndex: Int) -> MatchProfile {
        MatchProfile(
            id: login.uuid,
            firstName: name.first,
            lastName: name.last,
            email: email,
            phone: phone,
            cell: cell,
            gender: gender,
            age: dob.age,
            city: location.city,
            state: location.state,
            country: location.country,
            nationality: nat,
            registeredDate: RandomUser.iso8601.date(from: registered.date) ?? .now,
            thumbnailURLString: picture.large,
            largeImageURLString: picture.large,
            decision: .pending,
            sortIndex: sortIndex
        )
    }

    /// randomuser.me returns registration dates as ISO-8601 with fractional seconds.
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
