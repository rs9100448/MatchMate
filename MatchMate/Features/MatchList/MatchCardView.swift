//
//  MatchCardView.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI

/// A single match card. Reads `profile` directly — since `MatchProfile` is an
/// observable `@Model`, any decision change (made here or on the detail screen)
/// re-renders this card automatically.
struct MatchCardView: View {
    let profile: MatchProfile
    let onDecision: (MatchDecision) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                RemoteImage(url: profile.thumbnailURL)
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.quaternary, lineWidth: 1))

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(profile.fullName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(profile.age) · \(profile.location)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Divider()

            DecisionActionBar(decision: profile.decision, onDecision: onDecision)
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
