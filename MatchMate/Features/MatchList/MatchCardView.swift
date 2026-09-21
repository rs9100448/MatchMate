//
//  MatchCardView.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI

/// A single match card, laid out like the reference design: a circular photo
/// (medium-res so it stays crisp at avatar size), the name in the accent color,
/// an "age, location" subtitle, and the Accept/Decline controls (which become a
/// full-width status bar once decided).
///
/// Reads `profile` directly — since `MatchProfile` is an observable `@Model`,
/// any decision change (made here or on the detail screen) re-renders this card
/// automatically.
struct MatchCardView: View {
    let profile: MatchProfile
    let onDecision: (MatchDecision) -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            RemoteImage(url: profile.mediumImageURL)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(.quaternary, lineWidth: 1))
                .padding(.top, Theme.Spacing.sm)

            VStack(spacing: Theme.Spacing.xs) {
                Text(profile.fullName)
                    .font(.title3.bold())
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                Text("\(profile.age), \(profile.location)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            DecisionActionBar(decision: profile.decision, onDecision: onDecision)
                .padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.lg)
        .background(.background, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(.quaternary, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
