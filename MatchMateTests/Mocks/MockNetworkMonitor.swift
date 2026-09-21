//
//  MockNetworkMonitor.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

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
