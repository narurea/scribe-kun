import Foundation
import Observation

/// Downloads whisper models from Hugging Face into Application Support and tracks their state.
@MainActor
@Observable
final class ModelManager {
    enum State: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case failed(String)
    }

    let modelsDirectory: URL
    private(set) var states: [WhisperModel: State] = [:]
    @ObservationIgnored private var downloaders: [WhisperModel: ModelDownloader] = [:]
    /// Called after a model finishes downloading, so waiting files can start.
    @ObservationIgnored var onModelReady: ((WhisperModel) -> Void)?

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        modelsDirectory = support.appendingPathComponent("scribe-kun/models", isDirectory: true)
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        for model in WhisperModel.allCases {
            states[model] = fileManager.fileExists(atPath: fileURL(for: model).path) ? .downloaded : .notDownloaded
        }
    }

    func fileURL(for model: WhisperModel) -> URL {
        modelsDirectory.appendingPathComponent(model.fileName)
    }

    func state(for model: WhisperModel) -> State {
        states[model] ?? .notDownloaded
    }

    func isDownloaded(_ model: WhisperModel) -> Bool {
        state(for: model) == .downloaded
    }

    func download(_ model: WhisperModel) {
        switch state(for: model) {
        case .downloaded, .downloading: return
        case .notDownloaded, .failed: break
        }
        states[model] = .downloading(progress: 0)

        let downloader = ModelDownloader(
            source: model.downloadURL,
            destination: fileURL(for: model),
            onProgress: { [weak self] progress in
                Task { @MainActor in
                    guard let self, case .downloading = self.state(for: model) else { return }
                    self.states[model] = .downloading(progress: progress)
                }
            },
            onComplete: { [weak self] result in
                Task { @MainActor in self?.finishDownload(model, result: result) }
            }
        )
        downloaders[model] = downloader
        downloader.start()
    }

    func cancelDownload(_ model: WhisperModel) {
        downloaders[model]?.cancel()
    }

    private func finishDownload(_ model: WhisperModel, result: Result<Void, Error>) {
        downloaders[model] = nil
        switch result {
        case .success:
            states[model] = .downloaded
            onModelReady?(model)
        case .failure(let error as URLError) where error.code == .cancelled:
            states[model] = .notDownloaded
        case .failure(let error):
            states[model] = .failed(error.localizedDescription)
        }
    }
}

enum ModelDownloadError: LocalizedError {
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code): "ダウンロードに失敗しました（HTTP \(code)）"
        }
    }
}

/// URLSession download with byte-level progress. The file is moved into place only when complete,
/// so a cancelled or failed download never leaves a broken model behind.
private final class ModelDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let onProgress: @Sendable (Double) -> Void
    private let onComplete: @Sendable (Result<Void, Error>) -> Void
    private var task: URLSessionDownloadTask?
    private var finishError: Error?
    private var lastReported = 0.0

    init(
        source: URL,
        destination: URL,
        onProgress: @escaping @Sendable (Double) -> Void,
        onComplete: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        self.destination = destination
        self.onProgress = onProgress
        self.onComplete = onComplete
        super.init()
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session.downloadTask(with: source)
    }

    func start() { task?.resume() }

    func cancel() { task?.cancel() }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        if progress - lastReported >= 0.002 || progress >= 1 {
            lastReported = progress
            onProgress(progress)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let response = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            finishError = ModelDownloadError.httpStatus(response.statusCode)
            return
        }
        // The temporary file is deleted when this method returns, so move it now.
        do {
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)
        } catch {
            finishError = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let failure = error ?? finishError {
            onComplete(.failure(failure))
        } else {
            onComplete(.success(()))
        }
        session.finishTasksAndInvalidate()
    }
}
