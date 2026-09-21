import SwiftUI

/// Lightweight design tokens so spacing, radius, and semantic colors stay
/// consistent and are defined in one place.
enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 12
        static let pill: CGFloat = 999
    }

    enum Colors {
        static let accepted = Color.green
        static let declined = Color.red
        static let pending = Color.secondary
    }
}

extension MatchDecision {
    /// Semantic tint used by pills and buttons.
    var tint: Color {
        switch self {
        case .accepted: return Theme.Colors.accepted
        case .declined: return Theme.Colors.declined
        case .pending: return Theme.Colors.pending
        }
    }

    var systemImage: String {
        switch self {
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .pending: return "clock"
        }
    }
}
