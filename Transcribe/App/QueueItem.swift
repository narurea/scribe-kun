import Foundation
import Observation

@MainActor
@Observable
final class QueueItem: Identifiable {
    enum Status: Equatable {
        case waiting
        case extractingAudio(progress: Double)
        case transcribing(progress: Int)
        case completed
        case failed(String)
        case cancelled
    }

    let id = UUID()
    let url: URL
    /// True if `startAccessingSecurityScopedResource()` succeeded and must be balanced.
    let isAccessingSecurityScope: Bool
    @ObservationIgnored let cancellation = CancellationFlag()

    var status: Status = .waiting
    /// whisper language code, e.g. "ja".
    var detectedLanguage: String?
    var startedAt: Date?
    var finishedAt: Date?
    var outputURLs: [URL] = []

    init(url: URL, isAccessingSecurityScope: Bool) {
        self.url = url
        self.isAccessingSecurityScope = isAccessingSecurityScope
    }

    var fileName: String { url.lastPathComponent }

    var isVideo: Bool { AudioExtractor.videoExtensions.contains(url.pathExtension.lowercased()) }

    var isRunning: Bool {
        switch status {
        case .extractingAudio, .transcribing: true
        default: false
        }
    }

    var isFinished: Bool {
        switch status {
        case .completed, .failed, .cancelled: true
        default: false
        }
    }
}
