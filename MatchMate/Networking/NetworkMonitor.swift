//
//  NetworkMonitor.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import Foundation
import Network

/// Observable connectivity source. The list ViewModel reads `isConnected` to
/// decide whether to attempt a fetch and whether to show the offline banner.
@MainActor
protocol NetworkMonitoring: AnyObject {
    var isConnected: Bool { get }
}

/// `NWPathMonitor`-backed monitor.
///
/// Marked `@MainActor` + `@Observable` so SwiftUI can bind to `isConnected`
/// directly and updates are delivered on the main actor.
@MainActor
@Observable
final class NetworkMonitor: NetworkMonitoring {
    private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.matchmate.networkmonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
