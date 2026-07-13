import SwiftUI
import PhilipsKit

/// A glassy 0–9 numeric keypad with channel controls.
struct NumericKeypadView: View {
    @Environment(TVController.self) private var controller
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(1...9, id: \.self) { digit(  $0) }
                    GlassButton(systemImage: "delete.left", size: 72) {
                        Task { await controller.send(.back) }
                    }
                    digit(0)
                    GlassButton(systemImage: "checkmark", size: 72) {
                        Task { await controller.send(.confirm) }
                    }
                }
                HStack(spacing: 16) {
                    GlassPill(title: "Channel +", systemImage: "chevron.up") {
                        Task { await controller.send(.channelUp) }
                    }
                    GlassPill(title: "Channel −", systemImage: "chevron.down") {
                        Task { await controller.send(.channelDown) }
                    }
                }
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Keypad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .presentationDetents([.medium, .large])
        }
    }

    private func digit(_ value: Int) -> some View {
        Button {
            Haptics.shared.tap()
            if let key = RemoteKey.digit(value) { Task { await controller.send(key) } }
        } label: {
            Text("\(value)")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .frame(width: 72, height: 72)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
