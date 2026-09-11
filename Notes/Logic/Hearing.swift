import Foundation

/// What the dictate sheet says while nothing has been heard.
///
/// The sheet shows the words and nothing else: no meter, no waveform, no
/// spinner, in keeping with the rest of the app. So when no words arrive —
/// a covered microphone, a muted one, a language with no model — the line
/// that asks for them is the only thing that can say so, and it does it by
/// changing, the way "Asking…" and "Cleaning up…" do elsewhere.
///
/// Pure, so it is tested without the microphone.
enum Hearing {
    /// Long enough that someone who meant to speak has spoken.
    static let quiet: TimeInterval = 6
    /// Long enough that something is wrong rather than slow.
    static let silent: TimeInterval = 15

    static func placeholder(silence: TimeInterval) -> String {
        if silence >= silent { return "Nothing heard. The microphone may be covered or muted." }
        if silence >= quiet { return "Nothing heard yet." }
        return "Say what the note should say."
    }

    /// How long until the line would change, so the listener can sleep
    /// exactly that long and look again. Nil once it will not change
    /// again. This is what keeps a screen with no animation on it from
    /// needing a timer.
    static func next(after silence: TimeInterval) -> TimeInterval? {
        if silence < quiet { return quiet - silence }
        if silence < silent { return silent - silence }
        return nil
    }
}
