//
//  MatchDecision.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation

/// The user's decision about a match profile.
///
/// Stored as its `rawValue` (a `String`) inside SwiftData so the schema stays
/// stable and human-readable even if we add cases later.
enum MatchDecision: String, Codable, CaseIterable, Sendable {
    case pending
    case accepted
    case declined

    /// Short label surfaced on cards and the detail screen.
    var title: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        }
    }
}
