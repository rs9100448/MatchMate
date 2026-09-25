//
//  RootTabView.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI

struct RootTabView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            MatchListView(viewModel: dependencies.makeMatchListViewModel())
                .tabItem {
                    Label("Matches", systemImage: "heart.text.square")
                }

            SavedListView(viewModel: dependencies.makeSavedListViewModel())
                .tabItem {
                    Label("Saved", systemImage: "bookmark")
                }
        }
    }
}
