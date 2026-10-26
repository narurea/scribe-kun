import Foundation

/// Thread-safe cancel flag, polled from the audio reader loop and from whisper's abort callback.
final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

struct CancelledError: LocalizedError {
    var errorDescription: String? { "キャンセルされました" }
}
