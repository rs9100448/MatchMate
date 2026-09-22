//
//  MatchListView.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI

/// The match list screen. It's a thin projection of `viewModel.state`: it reads
/// the state machine and renders the matching branch — no local flags of its own.
struct MatchListView<ViewModel: MatchListViewModeling>: View {
    @State private var viewModel: ViewModel
    @Environment(AppDependencies.self) private var dependencies
    @Environment(NetworkMonitor.self) private var networkMonitor

    init(viewModel: ViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Profile Matches")
                .navigationDestination(for: MatchProfile.self) { profile in
                    MatchDetailView(
                        viewModel: dependencies.makeMatchDetailViewModel(for: profile)
                    )
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    banners
                }
        }
        .task {
            await viewModel.onAppear()
        }
    }

    // MARK: - Content (driven entirely by state)

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Finding matches…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            emptyState

        case let .loaded(profiles), let .paginating(profiles):
            list(profiles, isPaginating: viewModel.state.isPaginating)

        case let .failed(message, cached):
            if cached.isEmpty {
                errorState(message)
            } else {
                list(cached, isPaginating: false)
            }
        }
    }

    private func list(_ profiles: [MatchProfile], isPaginating: Bool) -> some View {
        List {
            ForEach(profiles) { profile in
                NavigationLink(value: profile) {
                    MatchCardView(profile: profile) { decision in
                        viewModel.setDecision(decision, for: profile)
                    }
                }
                .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                                          bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg))
                .listRowSeparator(.hidden)
                .buttonStyle(.plain)
                .task {
                    await viewModel.loadNextPageIfNeeded(currentItem: profile)
                }
            }

            if isPaginating {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No matches yet", systemImage: "heart.slash")
        } description: {
            Text(networkMonitor.isConnected
                 ? "Pull to refresh to load profiles."
                 : "You're offline and nothing is cached yet. Reconnect to load matches.")
        } actions: {
            Button("Reload") {
                Task { await viewModel.loadFirstPage() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load matches", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again") {
                Task { await viewModel.loadFirstPage() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Banners

    @ViewBuilder
    private var banners: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                BannerView(
                    text: "Offline — showing saved profiles. Accept/Decline still works.",
                    systemImage: "wifi.slash",
                    tint: .orange
                )
            }
            // Only show the inline error banner when there's content behind it;
            // a content-less failure is handled by the full-screen error state.
            if case let .failed(message, cached) = viewModel.state, !cached.isEmpty {
                BannerView(text: message, systemImage: "exclamationmark.triangle.fill", tint: .red) {
                    viewModel.dismissError()
                }
            }
        }
    }
}

/// Simple inline banner used for offline/error messaging.
private struct BannerView: View {
    let text: String
    let systemImage: String
    let tint: Color
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
            Text(text)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(tint)
    }
}
