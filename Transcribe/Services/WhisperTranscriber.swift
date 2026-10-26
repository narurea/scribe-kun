import Foundation
import whisper

struct TranscriptionResult: Sendable {
    var segments: [TranscriptSegment]
    /// whisper language code such as "ja", or nil if whisper did not report one.
    var languageCode: String?
}

enum TranscriptionError: LocalizedError {
    case modelLoadFailed(String)
    case failed(Int32)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let name): "モデル（\(name)）を読み込めませんでした。設定から再ダウンロードしてください"
        case .failed(let code): "文字起こしに失敗しました（コード \(code)）"
        }
    }
}

/// Wraps a whisper.cpp context. whisper contexts are not thread-safe, so every call runs on one serial queue.
/// The loaded model is kept between files so a queue of videos loads it only once.
final class WhisperTranscriber: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Transcribe.whisper", qos: .userInitiated)
    private var context: OpaquePointer?
    private var loadedModelPath: String?

    deinit {
        if let context { whisper_free(context) }
    }

    /// - Parameters:
    ///   - language: whisper language code, or "auto" to detect it.
    ///   - onLanguage: called once the language is known (detected or fixed).
    ///   - onProgress: whisper progress in percent (0...100).
    func transcribe(
        samples: [Float],
        modelURL: URL,
        language: String,
        cancellation: CancellationFlag,
        onLanguage: @escaping @Sendable (String) -> Void,
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws -> TranscriptionResult {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.run(
                        samples: samples, modelURL: modelURL, language: language,
                        cancellation: cancellation, onLanguage: onLanguage, onProgress: onProgress
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadContext(modelURL: URL) throws -> OpaquePointer {
        let path = modelURL.path
        if let context, loadedModelPath == path { return context }
        if let context {
            whisper_free(context)
            self.context = nil
            loadedModelPath = nil
        }

        var params = whisper_context_default_params()
        params.use_gpu = true
        params.flash_attn = true
        guard let newContext = whisper_init_from_file_with_params(path, params) else {
            throw TranscriptionError.modelLoadFailed(modelURL.lastPathComponent)
        }
        context = newContext
        loadedModelPath = path
        return newContext
    }

    private func run(
        samples: [Float],
        modelURL: URL,
        language: String,
        cancellation: CancellationFlag,
        onLanguage: @escaping @Sendable (String) -> Void,
        onProgress: @escaping @Sendable (Int) -> Void
    ) throws -> TranscriptionResult {
        if cancellation.isCancelled { throw CancelledError() }
        let ctx = try loadContext(modelURL: modelURL)

        let callbacks = Unmanaged.passRetained(
            CallbackBox(cancellation: cancellation, onLanguage: onLanguage, onProgress: onProgress)
        )
        defer { callbacks.release() }

        let languageCString = strdup(language)
        defer { free(languageCString) }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount)))
        params.language = UnsafePointer(languageCString)
        params.translate = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.print_special = false

        params.progress_callback = { _, state, progress, userData in
            guard let userData else { return }
            let box = Unmanaged<CallbackBox>.fromOpaque(userData).takeUnretainedValue()
            box.reportLanguage(id: whisper_full_lang_id_from_state(state))
            box.onProgress(Int(progress))
        }
        params.progress_callback_user_data = callbacks.toOpaque()

        params.abort_callback = { userData in
            guard let userData else { return false }
            return Unmanaged<CallbackBox>.fromOpaque(userData).takeUnretainedValue().cancellation.isCancelled
        }
        params.abort_callback_user_data = callbacks.toOpaque()

        let status = samples.withUnsafeBufferPointer { buffer in
            whisper_full(ctx, params, buffer.baseAddress, Int32(buffer.count))
        }
        if cancellation.isCancelled { throw CancelledError() }
        guard status == 0 else { throw TranscriptionError.failed(status) }

        let segmentCount = whisper_full_n_segments(ctx)
        var segments: [TranscriptSegment] = []
        segments.reserveCapacity(Int(segmentCount))
        for i in 0..<segmentCount {
            guard let text = whisper_full_get_segment_text(ctx, i) else { continue }
            // whisper reports times in centiseconds.
            segments.append(TranscriptSegment(
                start: Double(whisper_full_get_segment_t0(ctx, i)) / 100,
                end: Double(whisper_full_get_segment_t1(ctx, i)) / 100,
                text: String(cString: text)
            ))
        }

        return TranscriptionResult(segments: segments, languageCode: Self.languageCode(id: whisper_full_lang_id(ctx)))
    }

    fileprivate static func languageCode(id: Int32) -> String? {
        guard id >= 0, let code = whisper_lang_str(id) else { return nil }
        return String(cString: code)
    }
}

/// Passed to whisper's C callbacks through their `user_data` pointer.
private final class CallbackBox {
    let cancellation: CancellationFlag
    let onLanguage: @Sendable (String) -> Void
    let onProgress: @Sendable (Int) -> Void
    private var languageReported = false

    init(
        cancellation: CancellationFlag,
        onLanguage: @escaping @Sendable (String) -> Void,
        onProgress: @escaping @Sendable (Int) -> Void
    ) {
        self.cancellation = cancellation
        self.onLanguage = onLanguage
        self.onProgress = onProgress
    }

    func reportLanguage(id: Int32) {
        guard !languageReported, let code = WhisperTranscriber.languageCode(id: id) else { return }
        languageReported = true
        onLanguage(code)
    }
}
