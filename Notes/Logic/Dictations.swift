import Foundation

/// The one dictation whose tidying has not landed yet.
///
/// A dictated note is written and opened the moment the speaking stops,
/// with the words shaped by the pure rules, so there is never a wait. The
/// model is asked in parallel and its version arrives a few seconds later
/// as an edit to a note that is already there and already usable.
///
/// One at a time, because a person can only dictate one thing at a time.
/// That is why this is a single pending job and not a table of them.
///
/// App only: it reaches the model, which the widget extension cannot.
@MainActor
final class Dictations {
    static let shared = Dictations()

    /// The model gets as long as it does anywhere else in the app. Unlike
    /// everywhere else, nobody is waiting on it: the note is already open
    /// and can be read, edited or left before this ever comes back.
    static let limit: Duration = .seconds(20)

    private var noteID: UUID?
    private var job: Task<Dictation.Cleaning, Never>?
    /// Bumped whenever a job is cancelled, and so whenever one starts. An
    /// answer that comes back holding an older one is an answer nobody
    /// wants: since it was asked for, the user has started typing, left, or
    /// dictated something else.
    private var ticket = 0

    /// Starts the model on `heard` for the note just written from it. It
    /// begins at once, while the editor is still being pushed, so most of
    /// the thinking is done before anyone could look for it.
    func start(heard: String, for id: UUID) {
        cancel()
        noteID = id
        job = Task { @MainActor in
            await withTimeout(Self.limit) { await OnDevice.cleaned(dictation: heard) } ?? .tooSlow
        }
    }

    /// Whether this note is waiting on one. The editor asks before it has
    /// drawn anything, to decide whether to take the keyboard.
    func isPending(_ id: UUID) -> Bool { noteID == id && job != nil }

    /// Waits for this note's answer, or nil when there is nothing pending
    /// for it. Either way the job is finished with afterwards.
    func outcome(for id: UUID) async -> Dictation.Cleaning? {
        guard noteID == id, let job else { return nil }
        let mine = ticket
        let answer = await job.value
        // Cancelling was never able to stop this. `cancel()` cannot reach a
        // task that is already being awaited, so the answer arrives whatever
        // happens; what cancelling can do is make it unwanted, and this is
        // where that is noticed. Clearing is conditional for the same
        // reason: a newer dictation may have registered while this one was
        // still thinking, and finishing must not deregister that one.
        guard mine == ticket else { return nil }
        clear()
        return answer
    }

    /// The user took over, or left. Either way the model's version is no
    /// longer wanted: landing it on a note they have started editing would
    /// be a change they did not make and did not see coming.
    func cancel() {
        ticket &+= 1
        job?.cancel()
        clear()
    }

    private func clear() {
        job = nil
        noteID = nil
    }
}
