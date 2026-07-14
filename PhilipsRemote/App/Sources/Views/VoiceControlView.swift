import SwiftUI
import PhilipsKit

/// Hold‑to‑talk voice control. Transcribes speech, parses it into a command and
/// executes it against the TV.
struct VoiceControlView: View {
    @Environment(TVController.self) private var controller
    @Environment(\.dismiss) private var dismiss
    @State private var speech = SpeechService()
    @State private var lastResult: String?
    @State private var authorized = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                Text(speech.transcript.isEmpty ? "Hold the mic and speak" : speech.transcript)
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(speech.transcript.isEmpty ? .secondary : .primary)
                    .padding(.horizontal)
                    .animation(.smooth, value: speech.transcript)

                if let lastResult {
                    Label(lastResult, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                        .transition(.opacity)
                }

                Spacer()

                micButton

                Text("Try: “Open Netflix” · “Volume up” · “Search for Interstellar”")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)

                if !authorized {
                    Text("Enable Microphone & Speech Recognition in Settings to use voice.")
                        .font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
            }
            .padding()
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task { authorized = await speech.requestAuthorization() }
            .presentationDetents([.large])
        }
    }

    private var micButton: some View {
        ZStack {
            if speech.isRecording {
                Circle().fill(.tint.opacity(0.25))
                    .frame(width: 160, height: 160)
                    .scaleEffect(speech.isRecording ? 1.15 : 1)
                    .animation(.easeInOut(duration: 0.9).repeatForever(), value: speech.isRecording)
            }
            Circle()
                .fill(speech.isRecording ? AnyShapeStyle(.tint) : AnyShapeStyle(.ultraThinMaterial))
                .frame(width: 120, height: 120)
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                .overlay(
                    Image(systemName: "mic.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(speech.isRecording ? Color.white : Color.accentColor)
                )
                .shadow(color: .accentColor.opacity(0.5), radius: 16)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !speech.isRecording { startListening() } }
                .onEnded { _ in stopAndExecute() }
        )
        .accessibilityLabel("Hold to talk")
    }

    private func startListening() {
        guard authorized else { return }
        Haptics.shared.press()
        try? speech.start()
    }

    private func stopAndExecute() {
        speech.stop()
        let phrase = speech.transcript
        guard !phrase.isEmpty else { return }
        Task { await execute(VoiceCommandParser.parse(phrase)) }
    }

    private func execute(_ command: VoiceCommandParser.Command) async {
        switch command {
        case .key(let key):
            await controller.send(key)
            setResult("Sent \(key)")
        case .setVolume(let value):
            let scaled = Int(Double(value) / 100 * Double(controller.volumeRange.upperBound))
            await controller.setVolume(scaled)
            setResult("Volume \(value)%")
        case .launchApp(let name):
            if let app = controller.apps.first(where: { $0.label.localizedCaseInsensitiveContains(name) }) {
                await controller.launch(app)
                setResult("Opening \(app.label)")
            } else {
                setResult("Couldn't find \(name)")
            }
        case .search(let query):
            await controller.send(.confirm)
            await controller.sendText(query)
            setResult("Searching \(query)")
        case .unknown:
            setResult("Didn't catch that")
            Haptics.shared.warning()
        }
    }

    private func setResult(_ text: String) {
        withAnimation { lastResult = text }
        Haptics.shared.success()
    }
}
