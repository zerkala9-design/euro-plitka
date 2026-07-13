import SwiftUI

/// A frosted, rounded container that mimics the visionOS / Apple Home glass look
/// using `ultraThinMaterial`, a subtle gradient stroke and soft shadow.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Theme.cornerRadiusLarge
    var padding: CGFloat = Theme.spacing
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 12)
    }
}

/// A circular, tactile remote button with a glass surface, spring press
/// animation and haptic feedback. The visual anchor of the remote UI.
struct GlassButton: View {
    let systemImage: String
    var title: String? = nil
    var tint: Color = .white
    var size: CGFloat = Theme.buttonSize
    var prominent: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.shared.tap()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                if let title {
                    Text(title)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                if prominent {
                    Circle().fill(tint.opacity(0.22))
                } else {
                    Circle().fill(.ultraThinMaterial)
                }
            }
            .overlay(
                Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .scaleEffect(isPressed && !reduceMotion ? 0.9 : 1)
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { isPressed = false } }
        )
        .accessibilityLabel(title ?? systemImage)
    }
}

/// A pill‑shaped label button used for secondary actions.
struct GlassPill: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
