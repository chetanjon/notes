import Foundation

/// Waits for `work`, or gives up after `limit` and answers nil. The
/// on-device model is asked from two screens that show a spinner while it
/// thinks; without a limit a call that never returns leaves the spinner
/// turning with no way out but backing away from the screen.
func withTimeout<T: Sendable>(_ limit: Duration,
                              _ work: @escaping @Sendable () async -> T?) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await work() }
        group.addTask {
            try? await Task.sleep(for: limit)
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}
