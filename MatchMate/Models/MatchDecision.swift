//
//  MatchDecision.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation

enum MatchDecision: String, Codable, CaseIterable, Sendable {
    case pending
    case accepted
    case declined

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        }
    }
}
