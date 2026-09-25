//
//  ProfileRepository.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import SwiftData

@MainActor
protocol ProfileRepository: AnyObject {
    func cachedProfiles() throws -> [MatchProfile]
    @discardableResult
    func fetchAndStore(page: Int, pageSize: Int) async throws -> [MatchProfile]
    func setDecision(_ decision: MatchDecision, for profile: MatchProfile) throws
    func savedProfiles() throws -> [MatchProfile]
    func setSaved(_ saved: Bool, for profile: MatchProfile) throws
}

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

    func savedProfiles() throws -> [MatchProfile] {
        let descriptor = FetchDescriptor<MatchProfile>(
            predicate: #Predicate { $0.isSaved },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
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
                current.mediumImageURLString = mapped.mediumImageURLString
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
        // A decided profile leaves the "save for later" shortlist automatically.
        if decision == .accepted || decision == .declined {
            profile.isSaved = false
            profile.savedAt = nil
        }
        try save()
    }

    func setSaved(_ saved: Bool, for profile: MatchProfile) throws {
        profile.isSaved = saved
        profile.savedAt = saved ? .now : nil
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
