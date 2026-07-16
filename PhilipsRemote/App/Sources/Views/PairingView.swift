import SwiftUI
import PhilipsKit

/// Secure pairing flow with an animated hero, PIN entry and clear error states.
struct PairingView: View {
    let device: TVDevice

    @Environment(\.dismiss) private var dismiss
    @Environment(DeviceStore.self) private var store
    @Environment(AppModel.self) private var model

    @State private var vm = PairingViewModel()
    @State private var pin = ""
    @FocusState private var pinFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                PairingHero(phase: vm.phase)

                VStack(spacing: 8) {
                    Text(title).font(.title2.bold())
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if vm.phase == .awaitingPIN {
                    PINField(pin: $pin)
                        .focused($pinFocused)
                        .onChange(of: pin) { _, new in
                            if new.count == 6 { Task { await confirm() } }
                        }
                }

                if case .failed(let message) = vm.phase {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                actionButton
                    .padding(.horizontal)
            }
            .padding()
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Pair \(device.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await vm.begin(pairing: device) }
            .onChange(of: vm.phase) { _, phase in
                if phase == .awaitingPIN { pinFocused = true }
                if phase == .success { finishSuccess() }
            }
        }
    }

    private var title: String {
        switch vm.phase {
        case .requesting: return "Starting pairing…"
        case .awaitingPIN: return "Enter the code"
        case .confirming: return "Verifying…"
        case .success: return "Paired!"
        case .failed: return "Pairing failed"
        }
    }

    private var subtitle: String {
        switch vm.phase {
        case .requesting: return "Waking up \(device.model) and requesting a secure session."
        case .awaitingPIN: return "A 6‑character code is now shown on your TV screen. Type it here."
        case .confirming: return "Exchanging encrypted keys with your TV."
        case .success: return "Your TV is connected and the token is stored securely in the Keychain."
        case .failed: return "Let's try that again."
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch vm.phase {
        case .failed:
            GlassPill(title: "Try Again", systemImage: "arrow.clockwise") {
                pin = ""
                Task { await vm.begin(pairing: device) }
            }
        case .awaitingPIN:
            GlassPill(title: "Confirm", systemImage: "checkmark") {
                Task { await confirm() }
            }
        default:
            EmptyView()
        }
    }

    private func confirm() async {
        await vm.confirm(pin: pin)
    }

    private func finishSuccess() {
        var paired = device
        paired.isPaired = true
        paired.lastConnected = Date()
        store.upsert(paired)
        store.select(paired)
        Haptics.shared.success()
        Task {
            await model.controller.connect(to: paired)
            try? await Task.sleep(for: .seconds(0.8))
            dismiss()
        }
    }
}

/// Animated pairing hero: a pulsing glass ring around a TV glyph.
struct PairingHero: View {
    let phase: PairingViewModel.Phase
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(.tint.opacity(0.4 - Double(i) * 0.12), lineWidth: 2)
                    .frame(width: 120 + CGFloat(i) * 44, height: 120 + CGFloat(i) * 44)
                    .scaleEffect(pulse ? 1.08 : 0.94)
                    .animation(.easeInOut(duration: 1.4).repeatForever().delay(Double(i) * 0.2), value: pulse)
            }
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 116, height: 116)
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            Image(systemName: heroSymbol)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.tint)
                .contentTransition(.symbolEffect(.replace))
        }
        .onAppear { pulse = true }
    }

    private var heroSymbol: String {
        switch phase {
        case .success: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        default: return "tv.inset.filled"
        }
    }
}

/// 4‑digit segmented PIN entry.
struct PINField: View {
    @Binding var pin: String

    private let slots = 6
    private let hexChars = Set("0123456789ABCDEF")

    var body: some View {
        ZStack {
            TextField("", text: $pin)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(.clear)
                .tint(.clear)
                .onChange(of: pin) { _, new in
                    pin = String(new.uppercased().filter { hexChars.contains($0) }.prefix(slots))
                }
            HStack(spacing: 8) {
                ForEach(0..<slots, id: \.self) { index in
                    let char = index < pin.count ? String(Array(pin)[index]) : ""
                    Text(char)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .frame(width: 46, height: 60)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(index == pin.count ? Color.accentColor : .white.opacity(0.15),
                                              lineWidth: index == pin.count ? 2 : 1)
                        )
                }
            }
            .allowsHitTesting(false)
        }
    }
}
