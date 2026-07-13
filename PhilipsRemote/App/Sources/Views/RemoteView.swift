import SwiftUI
import PhilipsKit

/// The classic button remote: power/home/back row, a glass D‑pad with a center
/// OK, volume & channel rockers, colored keys and transport controls.
struct RemoteView: View {
    @Environment(TVController.self) private var controller

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                topRow
                DPadView()
                rockers
                coloredKeys
                transport
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
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
                onUp: { Task { await controller.volumeStep(up: true) } },
                onDown: { Task { await controller.volumeStep(up: false) } },
                onCenter: { Task { await controller.toggleMute() } }
            )
            RockerControl(
                topIcon: RemoteKey.channelUp.systemImage,
                bottomIcon: RemoteKey.channelDown.systemImage,
                centerIcon: "list.and.film",
                label: "CH",
                onUp: { Task { await controller.send(.channelUp) } },
                onDown: { Task { await controller.send(.channelDown) } },
                onCenter: { Task { await controller.send(.guide) } }
            )
        }
    }

    private var coloredKeys: some View {
        HStack(spacing: 16) {
            colorKey(.red, .red)
            colorKey(.green, .green)
            colorKey(.yellow, .yellow)
            colorKey(.blue, .blue)
        }
    }

    private func colorKey(_ key: RemoteKey, _ color: Color) -> some View {
        Button {
            Haptics.shared.tap()
            Task { await controller.send(key) }
        } label: {
            Circle()
                .fill(color.gradient)
                .frame(height: 26)
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                .shadow(color: color.opacity(0.5), radius: 6)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(.tint.opacity(0.9)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5))
                    .shadow(color: .accentColor.opacity(0.6), radius: 12)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 250, height: 250)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation pad")
    }

    private func directional(_ key: RemoteKey, alignment: Alignment) -> some View {
        Image(systemName: key.systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 60, height: 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .scaleEffect(pressedDirection == key && !reduceMotion ? 1.3 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.shared.tap()
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pressedDirection = key }
                Task {
                    await controller.send(key)
                    try? await Task.sleep(for: .seconds(0.15))
                    withAnimation { pressedDirection = nil }
                }
            }
            .accessibilityLabel("\(key)".capitalized)
    }
}

/// A vertical rocker (volume / channel) with a tappable center.
struct RockerControl: View {
    let topIcon: String
    let bottomIcon: String
    let centerIcon: String
    let label: String
    let onUp: () -> Void
    let onDown: () -> Void
    let onCenter: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            rockerButton(topIcon, action: onUp)
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
            rockerButton(bottomIcon, action: onDown)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.12)))
    }

    private func rockerButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.shared.tap(); action() }) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
