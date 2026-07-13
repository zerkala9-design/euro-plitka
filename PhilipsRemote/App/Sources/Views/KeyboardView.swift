import SwiftUI
import UIKit
import PhilipsKit

/// Remote keyboard. Uses the native iPhone keyboard (emoji, dictation, paste,
/// autofill all come for free) and streams text to the TV. Text is sent as the
/// user types so on‑screen fields update live.
struct KeyboardView: View {
    @Environment(TVController.self) private var controller
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SENDING TO TV")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("Type here…", text: $text, axis: .vertical)
                            .font(.title3)
                            .focused($focused)
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(.send)
                            .onSubmit { send() }
                            .onChange(of: text) { _, new in
                                Task { await controller.sendText(new) }
                            }
                    }
                }

                HStack(spacing: 14) {
                    GlassPill(title: "Paste", systemImage: "doc.on.clipboard") {
                        if let clip = UIPasteboard.general.string {
                            text = clip
                            Task { await controller.sendText(clip) }
                        }
                    }
                    GlassPill(title: "Clear", systemImage: "xmark.circle") { text = "" }
                    GlassPill(title: "Send", systemImage: "paperplane.fill") { send() }
                }

                Spacer()
            }
            .padding()
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task { focused = true }
            .presentationDetents([.medium, .large])
        }
    }

    private func send() {
        Task {
            await controller.sendText(text)
            await controller.send(.confirm)
        }
        Haptics.shared.success()
    }
}
