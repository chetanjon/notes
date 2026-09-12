import AVFoundation
import Foundation
import Speech

/// The microphone to words, on the phone: iOS's speech recognition with
/// on-device recognition required, so nothing spoken leaves the phone.
/// Started by holding the pencil; stopped by the button or by the sheet
/// going away. App only.
///
/// Two things here are not obvious and both are the point of the file.
///
/// A recognition does not run for ever: iOS stops one after about a
/// minute. So a long dictation is several of them, and the listener
/// rotates to a fresh request before the old one is cut off, keeping the
/// words in a `Transcript`. Without that, speaking for two minutes
/// silently loses everything after the first.
///
/// And a recognition's last word is not its best. The partial results
/// that arrive while someone speaks are guesses; asking the task to
/// finish makes it do a considered pass that fixes casing and
/// punctuation. That pass is worth a short wait, which is why stopping is
/// in two parts: `stop()` takes the microphone down at once, and
/// `settled(within:)` waits briefly for the better answer.
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
    /// What to say while nothing has been heard. The sheet shows the words
    /// and nothing else, so this line is the only way it can report that
    /// no words are arriving.
    private(set) var placeholder = Hearing.placeholder(silence: 0)
    /// Said under the words when something took the microphone away.
    private(set) var notice: String?

    /// A recognition is cut off by iOS after about a minute. Rotating
    /// before that keeps the words coming.
    private static let segment: TimeInterval = 45
    /// How long the considered pass may take before the partials are used
    /// instead. Stop must always let the user out.
    nonisolated static let finalWait: Duration = .seconds(2)

    /// Not a `let`: an engine is dead for good after the media server
    /// resets, and has to be replaced rather than restarted.
    private var engine = AVAudioEngine()
    /// The request the tap is feeding. Read on the audio thread, so it is
    /// only ever swapped behind the lock.
    private var sink: SFSpeechAudioBufferRecognitionRequest?
    private let sinkLock = NSLock()
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var vocabulary: [String] = []

    private var heard = Transcript()
    private var lastWords = Date.now
    private var quietTask: Task<Void, Never>?
    private var rotateTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var isFinal = false

    /// Set when the sheet goes while `start` is still waiting on a
    /// permission prompt. Without it, `stop` sees `.idle`, does nothing, and
    /// `start` carries on to open the microphone for a view that has gone.
    private var stopped = false

    /// - Parameter vocabulary: names out of the user's own notes, so they
    ///   come back spelled their way rather than as the nearest common
    ///   word. It never leaves the phone.
    func start(vocabulary: [String] = []) async {
        guard state != .listening else { return }
        stopped = false
        isFinal = false
        heard = Transcript()
        transcript = ""
        notice = nil
        self.vocabulary = vocabulary

        // Permission first, and availability afterwards. The other way
        // round, `isAvailable` is false only because nobody has been asked
        // yet, and a first-time user is told their language is not
        // supported when the truth is that they have not said yes.
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard !stopped else { return }
        switch speech {
        case .authorized:
            break
        case .restricted:
            // Not the same as off: this one the user cannot simply turn on.
            state = .failed("Speech recognition is not allowed on this iPhone. Screen Time can restrict it, in Settings › Screen Time › Content & Privacy Restrictions.")
            return
        default:
            state = .failed("Speech recognition is off. Turn it on in Settings › Privacy & Security › Speech Recognition.")
            return
        }

        let mic = await AVAudioApplication.requestRecordPermission()
        guard !stopped else { return }
        guard mic else {
            state = .failed("The microphone is off. Turn it on in Settings › Privacy & Security › Microphone.")
            return
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            state = .failed("Speech recognition is not available for your language.")
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            state = .failed("On-device speech recognition is not available for your language, so Matte does not listen.")
            return
        }
        self.recognizer = recognizer

        do {
            try openSession()
            try listen()
        } catch {
            state = .failed("The microphone could not be started.")
            teardown()
            return
        }
        lastWords = .now
        state = .listening
        watchForTrouble()
        scheduleQuiet()
        scheduleRotation()
    }

    /// Ends the listening. The microphone goes down at once; the words are
    /// whatever has been heard, which `settled(within:)` may still improve.
    func stop() {
        stopped = true
        quietTask?.cancel()
        rotateTask?.cancel()
        guard state == .listening else { return }
        sinkLock.lock()
        sink?.endAudio()
        sinkLock.unlock()
        // Finish, never cancel: cancelling throws away the considered pass
        // that fixes casing and punctuation, which is the whole reason to
        // wait a moment before using the words.
        task?.finish()
        closeMicrophone()
        state = .stopped
    }

    /// The words, once the recogniser's considered pass has arrived or the
    /// wait has run out. Safe to call more than once.
    func settled(within limit: Duration = finalWait) async -> String {
        if !isFinal, task != nil {
            // A poll rather than a continuation: the callback can fire
            // before, during or after this call, and a short wait that is
            // obviously bounded is worth more here than a clever one.
            let deadline = ContinuousClock.now.advanced(by: limit)
            while !isFinal, ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        finishTask()
        heard.settle()
        transcript = heard.text
        return transcript
    }

    // MARK: Listening

    private func openSession() throws {
        let session = AVAudioSession.sharedInstance()
        // Without the Bluetooth option a user wearing AirPods is recorded
        // by the phone across the room, which nobody would report as a bug
        // and everybody would feel.
        try session.setCategory(.record, mode: .measurement,
                                options: [.duckOthers, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Opens a request and starts a task on it, with the tap feeding it.
    private func listen() throws {
        guard let recognizer else { throw Trouble.noRecognizer }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        // Free, and the difference between a wall of words and sentences.
        request.addsPunctuation = true
        request.taskHint = .dictation
        // Apple's own limit is a hundred short phrases.
        request.contextualStrings = vocabulary

        sinkLock.lock()
        sink = request
        sinkLock.unlock()

        if !engine.isRunning {
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                // The audio thread. No actor hop and no allocation beyond
                // the append: this runs every twenty milliseconds or so.
                // Weakly, or the engine's tap would hold the listener and
                // the listener the engine.
                guard let self else { return }
                self.sinkLock.lock()
                defer { self.sinkLock.unlock() }
                self.sink?.append(buffer)
            }
            engine.prepare()
            try engine.start()
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.took(result: result, error: error)
            }
        }
    }

    private func took(result: SFSpeechRecognitionResult?, error: Error?) {
        // Results still matter after Stop: the considered pass arrives
        // then. They stop mattering once it has.
        guard !isFinal, state == .listening || state == .stopped else { return }
        if let result {
            let words = result.bestTranscription.formattedString
            if words != heard.volatile {
                heard.revise(words)
                transcript = heard.text
                lastWords = .now
                placeholder = Hearing.placeholder(silence: 0)
                scheduleQuiet()
            }
            if result.isFinal { isFinal = true }
        }
        guard error != nil || result?.isFinal == true else { return }
        if state == .listening, !stopped {
            // The recognition ended on its own, part way through a long
            // dictation. Keep the words and open another rather than
            // stopping, which is what used to happen silently.
            rotate()
        }
    }

    /// Rotates to a fresh recognition, keeping everything heard so far.
    ///
    /// The words settled here are the last partial rather than a
    /// considered pass: waiting for one at every boundary would make the
    /// text jump backwards and forwards on screen. The last segment, which
    /// is the one the user is looking at when they tap Stop, does get it.
    private func rotate() {
        heard.settle()
        transcript = heard.text
        finishTask()
        guard !stopped, state == .listening else { return }
        do {
            try listen()
            scheduleRotation()
        } catch {
            state = .failed("The microphone could not be started.")
            teardown()
        }
    }

    private func scheduleRotation() {
        rotateTask?.cancel()
        rotateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.segment))
            guard !Task.isCancelled, let self, self.state == .listening else { return }
            self.rotate()
        }
    }

    /// One sleep to the moment the wording changes, not a tick. The app has
    /// nothing that animates continuously and this does not become the
    /// first thing that does.
    private func scheduleQuiet() {
        quietTask?.cancel()
        guard heard.isEmpty else {
            placeholder = Hearing.placeholder(silence: 0)
            return
        }
        quietTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let silence = Date.now.timeIntervalSince(self.lastWords)
            guard let wait = Hearing.next(after: silence) else { return }
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled, self.state == .listening, self.heard.isEmpty else { return }
            self.placeholder = Hearing.placeholder(silence: Date.now.timeIntervalSince(self.lastWords))
            self.scheduleQuiet()
        }
    }

    // MARK: Trouble

    private enum Trouble: Error { case noRecognizer }

    /// A call, Siri, unplugged headphones, or the media server falling
    /// over. Without these the sheet says "Listening" at a dead microphone
    /// for as long as the user is willing to keep talking to it.
    private func watchForTrouble() {
        let centre = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers.append(centre.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: session, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor [weak self] in
                // No resuming: an interruption means a call or Siri, and the
                // user is gone for minutes. Keep what they said.
                self?.interrupted("The microphone was taken by something else. That is everything heard.")
            }
        })
        observers.append(centre.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: session, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.routeChanged() }
        })
        observers.append(centre.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                            object: session, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.mediaServicesReset() }
        })
    }

    private func interrupted(_ reason: String) {
        guard state == .listening else { return }
        heard.settle()
        transcript = heard.text
        notice = reason
        stop()
    }

    /// Headphones in or out. The engine's format is stale afterwards, so
    /// the tap has to be laid again on the new one.
    private func routeChanged() {
        guard state == .listening else { return }
        heard.settle()
        transcript = heard.text
        finishTask()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        do {
            try listen()
            scheduleRotation()
        } catch {
            interrupted("The microphone changed and could not be picked up again. That is everything heard.")
        }
    }

    /// Everything is gone, engine included. An engine cannot be restarted
    /// after this, only replaced.
    private func mediaServicesReset() {
        guard state == .listening else { return }
        heard.settle()
        transcript = heard.text
        finishTask()
        engine = AVAudioEngine()
        do {
            try openSession()
            try listen()
            scheduleRotation()
        } catch {
            interrupted("The microphone had to restart. That is everything heard.")
        }
    }

    // MARK: Taking it down

    private func finishTask() {
        task?.cancel()
        task = nil
        sinkLock.lock()
        sink = nil
        sinkLock.unlock()
    }

    private func closeMicrophone() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }

    private func teardown() {
        quietTask?.cancel()
        rotateTask?.cancel()
        finishTask()
        closeMicrophone()
    }
}
