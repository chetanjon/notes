import Foundation

/// Waits for `work`, or gives up after `limit` and answers nil. The
/// on-device model is asked from screens that show a spinner while it
/// thinks; without a limit a call that never returns leaves the spinner
/// turning with no way out but backing away from the screen.
///
/// The losing side is cancelled and its answer dropped. A task group
/// cannot do this: a group waits for every child before it returns, so a
/// timeout written that way would come back only once the slow work had
/// finished anyway, which is the hang it was meant to cut short.
func withTimeout<T: Sendable>(_ limit: Duration,
                              _ work: @escaping @Sendable () async -> T?) async -> T? {
    let answer = FirstAnswer<T>()
    let worker = Task {
        let made = await work()
        await answer.settle(made)
    }
    let timer = Task {
        try? await Task.sleep(for: limit)
        await answer.settle(nil)
    }
    // Both of those are unstructured, so cancelling whoever called this
    // does not reach them, and `wait()` is a continuation, which
    // cancellation does not interrupt either. Without this the caller stays
    // here for the whole limit after it has given up — and a dictation
    // cleanup cancelled because the user started typing came back anyway
    // and landed on top of what they had written.
    let result = await withTaskCancellationHandler {
        await answer.wait()
    } onCancel: {
        // Unblocks the wait. It cannot decide the answer, though: cancelling
        // the worker makes the work's own `try? await` return early with
        // whatever it had, and that would settle first.
        worker.cancel()
        timer.cancel()
        Task { await answer.settle(nil) }
    }
    worker.cancel()
    timer.cancel()
    // So the decision is made here, where it is not a race. A caller that
    // has given up gets nothing, whatever arrived while it was giving up.
    return Task.isCancelled ? nil : result
}

/// Whichever answer arrives first, once.
private actor FirstAnswer<T: Sendable> {
    private var value: T?
    private var settled = false
    private var waiter: CheckedContinuation<T?, Never>?

    func settle(_ answer: T?) {
        guard !settled else { return }
        settled = true
        value = answer
        if let waiter {
            self.waiter = nil
            waiter.resume(returning: answer)
        }
    }

    func wait() async -> T? {
        if settled { return value }
        return await withCheckedContinuation { continuation in
            waiter = continuation
        }
    }
}
