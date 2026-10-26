import AppKit
import Foundation
import Observation

/// Holds the file queue and processes it top to bottom, one file at a time.
@MainActor
@Observable
final class QueueController {
    private(set) var items: [QueueItem] = []
    /// Files rejected when added; shown in an alert and then cleared.
    var rejectedFiles: [String] = []

    @ObservationIgnored private let modelManager: ModelManager
    @ObservationIgnored private let transcriber = WhisperTranscriber()
    @ObservationIgnored private var isProcessing = false

    init(modelManager: ModelManager) {
        self.modelManager = modelManager
        modelManager.onModelReady = { [weak self] _ in self?.processNextIfNeeded() }
    }

    var hasFinishedItems: Bool { items.contains { $0.isFinished } }

    /// Validates each file with AVFoundation and queues the playable ones.
    func add(_ urls: [URL]) {
        Task {
            var rejected: [String] = []
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                do {
                    try await AudioExtractor.validate(url)
                    items.append(QueueItem(url: url, isAccessingSecurityScope: accessing))
                } catch {
                    if accessing { url.stopAccessingSecurityScopedResource() }
                    rejected.append("\(url.lastPathComponent)：\(error.localizedDescription)")
                }
            }
            rejectedFiles += rejected
            processNextIfNeeded()
        }
    }

    func cancel(_ item: QueueItem) {
        if item.status == .waiting {
            item.status = .cancelled
            item.finishedAt = .now
            releaseAccess(item)
        } else {
            item.cancellation.cancel()
        }
    }

    func removeFinished() {
        items.removeAll { $0.isFinished }
    }

    func showInFinder(_ item: QueueItem) {
        NSWorkspace.shared.activateFileViewerSelecting(item.outputURLs)
    }

    /// Starts the next waiting file unless one is running or the selected model is missing.
    func processNextIfNeeded() {
        guard !isProcessing, let item = items.first(where: { $0.status == .waiting }) else { return }
        let settings = TranscriptionSettings.current()
        guard modelManager.isDownloaded(settings.model) else { return }

        isProcessing = true
        Task {
            await process(item, settings: settings)
            isProcessing = false
            processNextIfNeeded()
        }
    }

    private func process(_ item: QueueItem, settings: TranscriptionSettings) async {
        item.startedAt = .now
        item.status = .extractingAudio(progress: 0)
        defer {
            item.finishedAt = .now
            releaseAccess(item)
        }

        do {
            let samples = try await AudioExtractor.extractSamples(
                from: item.url,
                cancellation: item.cancellation,
                onProgress: { progress in
                    Task { @MainActor in
                        if case .extractingAudio = item.status { item.status = .extractingAudio(progress: progress) }
                    }
                }
            )

            item.status = .transcribing(progress: 0)
            let result = try await transcriber.transcribe(
                samples: samples,
                modelURL: modelManager.fileURL(for: settings.model),
                language: settings.language,
                cancellation: item.cancellation,
                onLanguage: { code in
                    Task { @MainActor in item.detectedLanguage = code }
                },
                onProgress: { progress in
                    Task { @MainActor in
                        if case .transcribing = item.status { item.status = .transcribing(progress: progress) }
                    }
                }
            )
            if let code = result.languageCode { item.detectedLanguage = code }

            item.outputURLs = try OutputFolder.withAccess(bookmark: settings.outputFolderBookmark) { folder in
                try OutputWriter.write(result.segments, sourceURL: item.url, formats: settings.formats, to: folder)
            }
            item.status = .completed
            if settings.notifyOnCompletion {
                Notifier.shared.notify(title: "文字起こしが完了しました", body: item.fileName)
            }
        } catch {
            if item.cancellation.isCancelled {
                item.status = .cancelled
            } else {
                item.status = .failed(error.localizedDescription)
                if settings.notifyOnCompletion {
                    Notifier.shared.notify(title: "文字起こしに失敗しました", body: "\(item.fileName)：\(error.localizedDescription)")
                }
            }
        }
    }

    private func releaseAccess(_ item: QueueItem) {
        if item.isAccessingSecurityScope { item.url.stopAccessingSecurityScopedResource() }
    }
}
