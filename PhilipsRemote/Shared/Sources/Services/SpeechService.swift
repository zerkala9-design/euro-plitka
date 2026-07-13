import Foundation
import Observation
import Speech
import AVFoundation

/// Live speech‑to‑text using the Speech framework + `AVAudioEngine`.
///
/// Drives the "hold to talk" voice control. Emits partial transcriptions so the
/// UI can show text as the user speaks, then a final phrase on release.
@MainActor
@Observable
public final class SpeechService {

    public private(set) var transcript: String = ""
    public private(set) var isRecording: Bool = false
    public private(set) var authorizationDenied: Bool = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    public init() {}

    public func requestAuthorization() async -> Bool {
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        let micGranted = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        let ok = status == .authorized && micGranted
        authorizationDenied = !ok
        return ok
    }

    public func start() throws {
        guard !isRecording else { return }
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            // The callback runs off the main actor; hop back before touching state.
            let text = result?.bestTranscription.formattedString
            let finished = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = text }
                if finished { self.stop() }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    public func stop() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
