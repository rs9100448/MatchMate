//
//  MatchCardView.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI

struct MatchCardView: View {
    let profile: MatchProfile
    let onDecision: (MatchDecision) -> Void
    let onToggleSave: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.md) {
                RemoteImage(url: profile.largeImageURL)
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(profile.fullName)
                        .font(.title3.bold())
                        .lineLimit(1)

                    Text("\(profile.age) years old")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label(profile.cityCountry, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            DecisionActionBar(decision: profile.decision, onDecision: onDecision)
        }
        .padding(Theme.Spacing.lg)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: onToggleSave) {
                if profile.isSaved {
                    Label("Unsave", systemImage: "bookmark.slash")
                } else {
                    Label("Save for later", systemImage: "bookmark")
                }
            }
        }
    }
}
