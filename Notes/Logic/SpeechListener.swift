import AVFoundation
import Foundation
import Speech

/// The microphone to words, on the phone: iOS's speech recognition with
/// on-device recognition required, so nothing spoken leaves the phone.
/// Started by holding the pencil; stopped by the button or by the sheet
/// going away. App only.
@MainActor
@Observable
final class SpeechListener {
    enum State: Equatable {
        case idle
        case listening
        case stopped
        /// Why it could not listen, in a sentence for the sheet.
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var transcript = ""

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() async {
        guard state != .listening else { return }
        transcript = ""
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            state = .failed("Speech recognition is not available for your language.")
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            state = .failed("On-device speech recognition is not available for your language, so Matte does not listen.")
            return
        }
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else {
            state = .failed("Speech recognition is off. Turn it on in Settings › Privacy & Security › Speech Recognition.")
            return
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard mic else {
            state = .failed("The microphone is off. Turn it on in Settings › Privacy & Security › Microphone.")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true
            self.request = request
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            state = .listening
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true, self.state == .listening {
                        self.finish()
                    }
                }
            }
        } catch {
            state = .failed("The microphone could not be started.")
            finish()
        }
    }

    /// Ends the listening; the transcript is whatever was heard by then.
    func stop() {
        guard state == .listening else { return }
        request?.endAudio()
        finish()
    }

    private func finish() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if state == .listening { state = .stopped }
    }
}
