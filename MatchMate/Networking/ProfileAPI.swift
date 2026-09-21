import Foundation

/// Fetches pages of profiles from the remote API.
///
/// The repository depends on this protocol (not the concrete type) so it can be
/// swapped for a stub in tests.
protocol ProfileAPI: Sendable {
    /// Fetches a single page of results.
    /// - Parameters:
    ///   - page: 1-based page index.
    ///   - pageSize: Number of results per page.
    /// - Returns: Decoded API users in server order.
    func fetchProfiles(page: Int, pageSize: Int) async throws -> [RandomUser]
}

/// Concrete `randomuser.me` implementation.
///
/// The `seed` is fixed to `matchmate` so paging stays stable across the review,
/// exactly as the assignment requires.
struct RandomUserAPI: ProfileAPI {
    private let client: HTTPClient
    private let baseURL: URL
    private let seed: String

    init(
        client: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://randomuser.me/api/")!,
        seed: String = "matchmate"
    ) {
        self.client = client
        self.baseURL = baseURL
        self.seed = seed
    }

    func fetchProfiles(page: Int, pageSize: Int) async throws -> [RandomUser] {
        let request = try makeRequest(page: page, pageSize: pageSize)
        let (data, response) = try await client.data(for: request)

        guard (200..<300).contains(response.statusCode) else {
            throw AppError.requestFailed(status: response.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(RandomUserResponse.self, from: data)
            return decoded.results
        } catch {
            throw AppError.decodingFailed
        }
    }

    private func makeRequest(page: Int, pageSize: Int) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw AppError.unknown
        }
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "results", value: String(pageSize)),
            URLQueryItem(name: "seed", value: seed)
        ]
        guard let url = components.url else { throw AppError.unknown }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        return request
    }
}
