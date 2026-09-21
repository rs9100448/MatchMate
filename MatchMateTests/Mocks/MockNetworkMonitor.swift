import Foundation
@testable import MatchMate

/// Toggleable connectivity for exercising offline paths.
@MainActor
final class MockNetworkMonitor: NetworkMonitoring {
    var isConnected: Bool

    init(isConnected: Bool = true) {
        self.isConnected = isConnected
    }
}
