//
//  HTTPClient.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation

protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AppError.transport("Non-HTTP response")
            }
            return (data, http)
        } catch {
            throw AppError.map(error)
        }
    }
}
