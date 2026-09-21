//
//  DecisionControls.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI

/// A pill showing the current decision status (Accepted / Declined).
struct DecisionStatusPill: View {
    let decision: MatchDecision

    var body: some View {
        Label(decision.title, systemImage: decision.systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .foregroundStyle(decision.tint)
            .background(decision.tint.opacity(0.12), in: Capsule())
            .accessibilityLabel("Status: \(decision.title)")
    }
}

/// Accept / Decline buttons. When a decision already exists, the status pill is
/// shown instead — with a subtle "Undo" affordance back to pending.
///
/// Reused verbatim by both the list card and the detail screen so the two can
/// never drift apart visually or behaviorally.
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
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.declined)

                Button {
                    onDecision(.accepted)
                } label: {
                    Label("Accept", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.accepted)
            }
            .controlSize(prominent ? .large : .regular)

        case .accepted, .declined:
            HStack {
                DecisionStatusPill(decision: decision)
                Spacer(minLength: Theme.Spacing.sm)
                Button("Undo") { onDecision(.pending) }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
            }
        }
    }
}
