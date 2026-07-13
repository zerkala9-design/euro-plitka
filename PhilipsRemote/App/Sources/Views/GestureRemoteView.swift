import SwiftUI
import PhilipsKit

/// A full‑surface trackpad. Swipes map to D‑pad navigation, a tap confirms,
/// double‑tap toggles play/pause, and a long press goes back. Momentum on a
/// fast swipe sends repeated steps, mimicking the Apple TV Remote feel.
struct GestureRemoteView: View {
    @Environment(TVController.self) private var controller
    @State private var ripple: CGPoint?
    @State private var lastSwipe: Date = .distantPast

    var body: some View {
        VStack(spacing: 14) {
            GlassCard {
                ZStack {
                    LinearGradient(colors: [.tintSoft.opacity(0.15), .clear],
                                   startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 10) {
                        Image(systemName: "hand.draw.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.tint)
                        Text("Swipe to navigate · Tap to select")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("Double‑tap: Play/Pause · Long press: Back")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let ripple {
                        Circle()
                            .fill(.tint.opacity(0.25))
                            .frame(width: 80, height: 80)
                            .position(ripple)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 360)
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .onTapGesture(count: 2) {
                    Haptics.shared.press()
                    Task { await controller.send(.playPause) }
                }
                .onTapGesture { location in
                    showRipple(at: location)
                    Haptics.shared.tap()
                    Task { await controller.send(.confirm) }
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    Haptics.shared.edge()
                    Task { await controller.send(.back) }
                }
            }

            HStack(spacing: 14) {
                GlassButton(systemImage: RemoteKey.back.systemImage, title: "Back", size: 56) {
                    Task { await controller.send(.back) }
                }
                GlassButton(systemImage: RemoteKey.home.systemImage, title: "Home", size: 56) {
                    Task { await controller.send(.home) }
                }
                GlassButton(systemImage: RemoteKey.playPause.systemImage, title: "Play", size: 56) {
                    Task { await controller.send(.playPause) }
                }
                GlassButton(systemImage: RemoteKey.options.systemImage, title: "Options", size: 56) {
                    Task { await controller.send(.options) }
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let now = Date()
                guard now.timeIntervalSince(lastSwipe) > 0.12 else { return }
                lastSwipe = now
                let dx = value.translation.width
                let dy = value.translation.height
                let key: RemoteKey = abs(dx) > abs(dy)
                    ? (dx > 0 ? .right : .left)
                    : (dy > 0 ? .down : .up)
                Haptics.shared.tap()
                let velocity = hypot(value.predictedEndTranslation.width - dx,
                                     value.predictedEndTranslation.height - dy)
                let steps = velocity > 220 ? 2 : 1     // momentum
                Task {
                    for _ in 0..<steps { await controller.send(key) }
                }
            }
    }

    private func showRipple(at point: CGPoint) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { ripple = point }
        Task {
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation { ripple = nil }
        }
    }
}

extension ShapeStyle where Self == Color {
    static var tintSoft: Color { .accentColor }
}
