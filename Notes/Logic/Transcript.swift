import Foundation

/// The words heard so far, across however many recognition segments it took.
///
/// A long dictation is not one recognition: iOS's older recogniser stops on
/// its own after about a minute, so the listener finishes that segment and
/// starts another. What is already settled cannot change again; the segment
/// in progress is rewritten with almost every buffer, which is why it is
/// held apart and replaced rather than appended to.
///
/// Pure, so it is tested without the microphone.
struct Transcript: Equatable {
    /// Segments that are done with. This only ever grows.
    private(set) var settled = ""
    /// The segment in progress, as the recogniser currently hears it.
    private(set) var volatile = ""

    var text: String { Transcript.joining(settled, volatile) }

    var isEmpty: Bool { text.isEmpty }

    /// The recogniser's latest reading of the segment in progress. It
    /// replaces the last one: a partial result is the whole segment as
    /// heard so far, not the words since the last call.
    mutating func revise(_ tail: String) {
        volatile = tail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The segment is done. `final`, where the recogniser gave one, is its
    /// considered version and replaces the last partial, which is usually
    /// worse: it is the pass that fixes casing and punctuation.
    /// A segment that heard nothing adds nothing, not a space.
    mutating func settle(_ final: String? = nil) {
        if let final { revise(final) }
        settled = Transcript.joining(settled, volatile)
        volatile = ""
    }

    /// One space between segments, never two, and never a leading one.
    private static func joining(_ first: String, _ second: String) -> String {
        if first.isEmpty { return second }
        if second.isEmpty { return first }
        return first + " " + second
    }
}
