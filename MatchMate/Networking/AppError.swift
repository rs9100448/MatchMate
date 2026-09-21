//
//  AppError.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation

/// A single, user-facing error type the whole app can present.
///
/// Lower layers throw specific errors; the repository/ViewModel translate them
/// into one of these cases so the UI has a stable, friendly surface.
enum AppError: LocalizedError, Equatable {
    case offline
    case requestFailed(status: Int)
    case decodingFailed
    case transport(String)
    case persistence(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .offline:
            return "You're offline. Showing saved profiles — you can still Accept or Decline."
        case .requestFailed(let status):
            return "The server responded with an error (\(status)). Please try again."
        case .decodingFailed:
            return "We couldn't read the data from the server."
        case .transport(let message):
            return "Network problem: \(message)"
        case .persistence(let message):
            return "Couldn't save your change: \(message)"
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    /// Normalizes any thrown error into an `AppError`.
    static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return .offline
            default:
                return .transport(urlError.localizedDescription)
            }
        }
        if error is DecodingError { return .decodingFailed }
        return .unknown
    }
}
