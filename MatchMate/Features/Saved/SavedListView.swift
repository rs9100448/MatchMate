//
//  SavedListView.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI

struct SavedListView<ViewModel: SavedListViewModeling>: View {
    @State private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Saved")
        }
        .onAppear {
            // Reload each time the tab is shown so saves made on the Matches
            // tab appear here, and decided/unsaved profiles drop off.
            viewModel.reload()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.saved.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.saved) { profile in
                MatchCardView(
                    profile: profile,
                    onDecision: { viewModel.setDecision($0, for: profile) },
                    onToggleSave: { viewModel.toggleSave(for: profile) }
                )
                .listRowInsets(EdgeInsets(top: Theme.Spacing.sm,
                                          leading: Theme.Spacing.lg,
                                          bottom: Theme.Spacing.sm,
                                          trailing: Theme.Spacing.lg))
                .listRowSeparator(.hidden)
            }
        }
        .scrollIndicators(.hidden)
        .listStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No saved profiles", systemImage: "bookmark")
        } description: {
            Text("Long-press a match and choose Save for later.")
        }
    }
}
