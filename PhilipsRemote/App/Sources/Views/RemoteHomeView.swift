import SwiftUI
import PhilipsKit

/// The main remote screen. Hosts the device switcher, a mode picker
/// (Buttons / Trackpad) and quick sheets for voice, keyboard, sources, numbers.
struct RemoteHomeView: View {
    @Environment(TVController.self) private var controller
    @Environment(DeviceStore.self) private var store

    @State private var mode: Mode = .buttons
    @State private var activeSheet: Sheet?

    enum Mode: String, CaseIterable { case buttons = "Buttons", trackpad = "Trackpad" }
    enum Sheet: String, Identifiable {
        case voice, keyboard, sources, numbers, info, devices
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                modePicker

                Group {
                    switch mode {
                    case .buttons: RemoteView()
                    case .trackpad: GestureRemoteView()
                    }
                }
                .frame(maxHeight: .infinity)

                quickActions
            }
            .padding()
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(store.selectedDevice?.displayName ?? "Remote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { activeSheet = .devices } label: {
                        Image(systemName: "rectangle.stack.badge.play")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = .info } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .voice: VoiceControlView()
                case .keyboard: KeyboardView()
                case .sources: SourcesView()
                case .numbers: NumericKeypadView()
                case .info: TVInfoView()
                case .devices: DevicesView()
                }
            }
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, _ in Haptics.shared.selectionChanged() }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            quick("Voice", "mic.fill") { activeSheet = .voice }
            quick("Keyboard", "keyboard.fill") { activeSheet = .keyboard }
            quick("Sources", "rectangle.connected.to.line.below") { activeSheet = .sources }
            quick("123", "number") { activeSheet = .numbers }
        }
    }

    private func quick(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.shared.tap(); action() }) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
