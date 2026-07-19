import SwiftUI
import PhilipsKit

/// The classic button remote: power/home/back row, a glass D‑pad with a center
/// OK, volume & channel rockers, colored keys and transport controls.
struct RemoteView: View {
    @Environment(TVController.self) private var controller

    var body: some View {
        VStack(spacing: 12) {
            topRow
            Spacer(minLength: 6)
            DPadView()
            Spacer(minLength: 6)
            rockers
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topRow: some View {
        HStack(spacing: 18) {
            GlassButton(systemImage: RemoteKey.standby.systemImage, title: "Power",
                        tint: .red, prominent: true) {
                Task { await controller.powerToggle() }
            }
            GlassButton(systemImage: RemoteKey.home.systemImage, title: "Home") {
                Task { await controller.send(.home) }
            }
            GlassButton(systemImage: RemoteKey.back.systemImage, title: "Back") {
                Task { await controller.send(.back) }
            }
            GlassButton(systemImage: RemoteKey.settings.systemImage, title: "Settings") {
                Task { await controller.send(.settings) }
            }
        }
    }

    private var rockers: some View {
        HStack(spacing: 24) {
            RockerControl(
                topIcon: RemoteKey.volumeUp.systemImage,
                bottomIcon: RemoteKey.volumeDown.systemImage,
                centerIcon: controller.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: "VOL",
                onUp: { down in down ? controller.beginHold(.volumeUp) : controller.endHold() },
                onDown: { down in down ? controller.beginHold(.volumeDown) : controller.endHold() },
                onCenter: { Task { await controller.toggleMute() } }
            )
            RockerControl(
                topIcon: "plus",       // match the volume rocker's look
                bottomIcon: "minus",
                centerIcon: "list.and.film",
                label: "CH",
                onUp: { down in down ? controller.beginHold(.channelUp) : controller.endHold() },
                onDown: { down in down ? controller.beginHold(.channelDown) : controller.endHold() },
                onCenter: { Task { await controller.send(.guide) } }
            )
        }
    }

    private var transport: some View {
        HStack(spacing: 14) {
            transportButton(.previous)
            transportButton(.rewind)
            transportButton(.playPause)
            transportButton(.fastForward)
            transportButton(.next)
        }
    }

    private func transportButton(_ key: RemoteKey) -> some View {
        GlassButton(systemImage: key.systemImage, size: 52) {
            Task { await controller.send(key) }
        }
    }
}

/// A directional pad with an inner glass ring and a springy center OK button.
struct DPadView: View {
    @Environment(TVController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressedDirection: RemoteKey?

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)

            directional(.up, alignment: .top)
            directional(.down, alignment: .bottom)
            directional(.left, alignment: .leading)
            directional(.right, alignment: .trailing)

            Button {
                Haptics.shared.press()
                Task { await controller.send(.confirm) }
            } label: {
                Text("OK")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(.tint.opacity(0.9)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5))
                    .shadow(color: .accentColor.opacity(0.6), radius: 10)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 216, height: 216)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation pad")
    }

    private func directional(_ key: RemoteKey, alignment: Alignment) -> some View {
        // The tappable area is the bounded 76×76 box; expanding to the full
        // frame afterwards only *positions* it at the edge, so each arrow reacts
        // only in its own region (otherwise the top view in the ZStack would
        // swallow every touch).
        Image(systemName: key.systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.secondary)
            .scaleEffect(pressedDirection == key && !reduceMotion ? 1.3 : 1)
            .frame(width: 76, height: 76)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard pressedDirection != key else { return }
                        Haptics.shared.tap()
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pressedDirection = key }
                        controller.beginPress(key)    // hold like a physical remote
                    }
                    .onEnded { _ in
                        controller.endPress()
                        withAnimation { pressedDirection = nil }
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .accessibilityLabel("\(key)".capitalized)
    }
}

/// A vertical rocker (volume / channel) with a tappable center.
struct RockerControl: View {
    let topIcon: String
    let bottomIcon: String
    let centerIcon: String
    let label: String
    /// Called with `true` on press and `false` on release (for auto‑repeat).
    let onUp: (Bool) -> Void
    let onDown: (Bool) -> Void
    let onCenter: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            rockerButton(topIcon, hold: onUp)
            Divider().background(.white.opacity(0.1))
            Button(action: { Haptics.shared.tap(); onCenter() }) {
                VStack(spacing: 2) {
                    Image(systemName: centerIcon).font(.subheadline)
                    Text(label).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            Divider().background(.white.opacity(0.1))
            rockerButton(bottomIcon, hold: onDown)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.12)))
    }

    private func rockerButton(_ icon: String, hold: @escaping (Bool) -> Void) -> some View {
        HoldButton(hold: hold) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
                .foregroundStyle(.primary)
        }
    }
}

/// A button that fires `hold(true)` on press and `hold(false)` on release, so
/// the caller can auto‑repeat an action while it's held down.
struct HoldButton<Label: View>: View {
    let hold: (Bool) -> Void
    @ViewBuilder var label: Label
    @State private var isPressed = false

    var body: some View {
        label
            .contentShape(Rectangle())
            .opacity(isPressed ? 0.5 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        Haptics.shared.tap()
                        hold(true)
                    }
                    .onEnded { _ in
                        isPressed = false
                        hold(false)
                    }
            )
    }
}
