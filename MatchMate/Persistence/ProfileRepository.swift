import Foundation
import SwiftData

/// Domain-facing persistence boundary.
///
/// The ViewModels depend only on this protocol — they never see `URLSession`,
/// `ModelContext`, or the API DTOs. This keeps UI logic thin and makes the
/// ViewModels trivially testable with an in-memory or stub repository.
///
/// `@MainActor` because it operates on the SwiftData main `ModelContext` and
/// returns live `@Model` objects that the SwiftUI views bind to directly.
@MainActor
protocol ProfileRepository: AnyObject {
    /// All cached profiles in paging order (offline-first read).
    func cachedProfiles() throws -> [MatchProfile]

    /// Fetches `page` from the API and upserts it into the store, preserving any
    /// existing decision. Returns the freshly merged, ordered list.
    @discardableResult
    func fetchAndStore(page: Int, pageSize: Int) async throws -> [MatchProfile]

    /// Persists a decision for a profile. The mutation is visible immediately to
    /// every view holding the same `@Model` instance.
    func setDecision(_ decision: MatchDecision, for profile: MatchProfile) throws
}

/// SwiftData-backed implementation.
final class SwiftDataProfileRepository: ProfileRepository {
    private let context: ModelContext
    private let api: ProfileAPI

    init(context: ModelContext, api: ProfileAPI) {
        self.context = context
        self.api = api
    }

    // MARK: - Reads

    func cachedProfiles() throws -> [MatchProfile] {
        let descriptor = FetchDescriptor<MatchProfile>(
            sortBy: [SortDescriptor(\.sortIndex, order: .forward)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw AppError.persistence(error.localizedDescription)
        }
    }

    // MARK: - Sync

    @discardableResult
    func fetchAndStore(page: Int, pageSize: Int) async throws -> [MatchProfile] {
        let users = try await api.fetchProfiles(page: page, pageSize: pageSize)
        try upsert(users, page: page, pageSize: pageSize)
        return try cachedProfiles()
    }

    /// Inserts new profiles and updates existing ones **without** overwriting the
    /// saved decision — the single most important rule for status consistency.
    private func upsert(_ users: [RandomUser], page: Int, pageSize: Int) throws {
        let incomingIDs = users.map(\.login.uuid)
        let existing = try fetchExisting(ids: incomingIDs)
        let baseIndex = (page - 1) * pageSize

        for (offset, user) in users.enumerated() {
            let sortIndex = baseIndex + offset
            if let current = existing[user.login.uuid] {
                // Refresh mutable fields; keep the user's decision intact.
                let mapped = user.asDomain(sortIndex: sortIndex)
                current.firstName = mapped.firstName
                current.lastName = mapped.lastName
                current.email = mapped.email
                current.phone = mapped.phone
                current.cell = mapped.cell
                current.gender = mapped.gender
                current.age = mapped.age
                current.city = mapped.city
                current.state = mapped.state
                current.country = mapped.country
                current.nationality = mapped.nationality
                current.registeredDate = mapped.registeredDate
                current.thumbnailURLString = mapped.thumbnailURLString
                current.largeImageURLString = mapped.largeImageURLString
                current.sortIndex = sortIndex
            } else {
                context.insert(user.asDomain(sortIndex: sortIndex))
            }
        }

        try save()
    }

    private func fetchExisting(ids: [String]) throws -> [String: MatchProfile] {
        let descriptor = FetchDescriptor<MatchProfile>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        do {
            let matches = try context.fetch(descriptor)
            return Dictionary(matches.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            throw AppError.persistence(error.localizedDescription)
        }
    }

    // MARK: - Writes

    func setDecision(_ decision: MatchDecision, for profile: MatchProfile) throws {
        profile.decision = decision
        try save()
    }

    private func save() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            throw AppError.persistence(error.localizedDescription)
        }
    }
}
