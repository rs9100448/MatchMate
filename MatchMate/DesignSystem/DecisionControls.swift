//
//  DecisionControls.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI

struct DecisionStatusBar: View {
    let decision: MatchDecision

    var body: some View {
        Label(decision.title, systemImage: decision.systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(decision.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(decision.tint.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .accessibilityLabel("Status: \(decision.title)")
    }
}

struct DecisionActionBar: View {
    let decision: MatchDecision
    var prominent: Bool = false
    let onDecision: (MatchDecision) -> Void

    var body: some View {
        switch decision {
        case .pending:
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    onDecision(.declined)
                } label: {
                    Label("Decline", systemImage: "xmark")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.gray)

                Button {
                    onDecision(.accepted)
                } label: {
                    Label("Accept", systemImage: "heart.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)

        case .accepted, .declined:
            DecisionStatusBar(decision: decision)
        }
    }
}
