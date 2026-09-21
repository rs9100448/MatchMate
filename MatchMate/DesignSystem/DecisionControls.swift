//
//  DecisionControls.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI

/// A full-width status bar shown once a decision is made — a clear text label
/// ("Accepted" / "Declined"), matching the reference design's "After Accept" /
/// "After Decline" states. Deliberately text, not an icon.
struct DecisionStatusBar: View {
    let decision: MatchDecision

    var body: some View {
        Text(decision.title)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(decision.tint, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            .accessibilityLabel("Status: \(decision.title)")
    }
}

/// Accept / Decline controls. Pending shows two labelled text buttons; once a
/// decision is made it's final and the buttons are replaced by a full-width
/// text status bar (never an icon).
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
                    Text("Decline").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.declined)

                Button {
                    onDecision(.accepted)
                } label: {
                    Text("Accept").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.accepted)
            }
            .controlSize(prominent ? .large : .regular)

        case .accepted, .declined:
            DecisionStatusBar(decision: decision)
        }
    }
}
