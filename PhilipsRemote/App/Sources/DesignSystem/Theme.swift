import SwiftUI

/// App‑wide design tokens: colors, gradients, corner radii and spacing.
/// The app is dark‑mode only with a configurable accent (default Philips Blue).
enum Theme {

    // MARK: - Accent

    enum Accent: String, CaseIterable, Identifiable {
        case philipsBlue = "Philips Blue"
        case violet = "Violet"
        case teal = "Teal"
        case sunset = "Sunset"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .philipsBlue: return Color(hex: 0x0B5ED7)
            case .violet:      return Color(hex: 0x7C5CFC)
            case .teal:        return Color(hex: 0x1FB6A6)
            case .sunset:      return Color(hex: 0xFF6B4A)
            }
        }

        var gradient: LinearGradient {
            LinearGradient(
                colors: [color.opacity(0.95), color.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Surfaces

    static let background = LinearGradient(
        colors: [
            Color(hex: 0x0A0A0F),
            Color(hex: 0x121218),
            Color(hex: 0x0A0A0F)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cornerRadiusLarge: CGFloat = 28
    static let cornerRadiusMedium: CGFloat = 20
    static let cornerRadiusSmall: CGFloat = 14

    static let spacing: CGFloat = 16
    static let buttonSize: CGFloat = 66
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

