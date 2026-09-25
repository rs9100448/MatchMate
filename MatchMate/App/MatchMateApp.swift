//
//  MatchMateApp.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI
import SwiftData

@main
struct MatchMateApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: dependencies)
                .environment(dependencies)
                .environment(dependencies.networkMonitor)
        }
        .modelContainer(dependencies.container)
    }
}
