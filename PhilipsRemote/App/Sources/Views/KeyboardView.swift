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
    @State private var debounce: Task<Void, Never>?
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
                                // Send once the user pauses, not on every key,
                                // so the TV applies one clean field update.
                                debounce?.cancel()
                                debounce = Task {
                                    try? await Task.sleep(for: .milliseconds(180))
                                    guard !Task.isCancelled else { return }
                                    await controller.sendText(new)
                                }
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
                    GlassPill(title: "Clear", systemImage: "xmark.circle") {
                        text = ""
                        Task { await controller.sendText("") }
                    }
                    GlassPill(title: "Send", systemImage: "paperplane.fill") { send() }
                }

                Text("Open a search or text field on the TV first, then type here — the text appears on the TV as you type. Press Send to confirm the search.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

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
        debounce?.cancel()
        Task {
            await controller.sendText(text)          // ensure latest text is set
            try? await Task.sleep(for: .milliseconds(120))
            await controller.submitText()            // IME Enter (search), not OK
        }
        Haptics.shared.success()
    }
}
