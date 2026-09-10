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
    let result = await answer.wait()
    worker.cancel()
    timer.cancel()
    return result
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
