import AVFoundation
import UniformTypeIdentifiers

enum AudioExtractionError: LocalizedError {
    case unsupportedFormat(String)
    case noAudioTrack
    case unreadable(Error?)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            "対応していない形式です（.\(ext)）。mp4 / mov / m4v / m4a / mp3 / wav に対応しています"
        case .noAudioTrack:
            "音声トラックが見つかりません"
        case .unreadable(let error):
            "音声を読み込めませんでした" + (error.map { "：\($0.localizedDescription)" } ?? "")
        }
    }
}

/// Reads the audio track of a media file as 16 kHz mono Float32 samples using AVFoundation.
enum AudioExtractor {
    static let sampleRate = 16_000

    static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v", "m4a", "mp3", "wav"]
    static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    static let supportedTypes: [UTType] =
        [UTType.mpeg4Movie, .quickTimeMovie, .mpeg4Audio, .mp3, .wav]
        + [UTType("com.apple.m4v-video")].compactMap { $0 }

    /// Checks the extension and that AVFoundation can find an audio track.
    static func validate(_ url: URL) async throws {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw AudioExtractionError.unsupportedFormat(ext.isEmpty ? "拡張子なし" : ext)
        }
        let tracks: [AVAssetTrack]
        do {
            tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .audio)
        } catch {
            throw AudioExtractionError.unreadable(error)
        }
        guard !tracks.isEmpty else { throw AudioExtractionError.noAudioTrack }
    }

    /// Decodes the first audio track. `onProgress` receives 0...1 based on the media duration.
    static func extractSamples(
        from url: URL,
        cancellation: CancellationFlag,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioExtractionError.noAudioTrack
        }
        let duration = try await asset.load(.duration).seconds

        // AVAssetReader blocks while decoding, so keep it off the Swift concurrency pool.
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let samples = try readSamples(
                        asset: asset, track: track, duration: duration,
                        cancellation: cancellation, onProgress: onProgress
                    )
                    continuation.resume(returning: samples)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func readSamples(
        asset: AVAsset,
        track: AVAssetTrack,
        duration: Double,
        cancellation: CancellationFlag,
        onProgress: @Sendable (Double) -> Void
    ) throws -> [Float] {
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw AudioExtractionError.unreadable(error)
        }

        // AVAssetReader resamples and downmixes to the requested format.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AudioExtractionError.unreadable(nil) }
        reader.add(output)
        guard reader.startReading() else { throw AudioExtractionError.unreadable(reader.error) }

        let expectedCount = duration.isFinite && duration > 0 ? Int(duration * Double(sampleRate)) : 0
        var samples: [Float] = []
        samples.reserveCapacity(expectedCount + sampleRate)
        var lastReported = 0.0

        while let sampleBuffer = output.copyNextSampleBuffer() {
            if cancellation.isCancelled {
                reader.cancelReading()
                throw CancelledError()
            }
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            let count = CMBlockBufferGetDataLength(blockBuffer) / MemoryLayout<Float>.size
            guard count > 0 else { continue }

            let offset = samples.count
            samples.append(contentsOf: repeatElement(0, count: count))
            let status = samples.withUnsafeMutableBytes { raw in
                CMBlockBufferCopyDataBytes(
                    blockBuffer,
                    atOffset: 0,
                    dataLength: count * MemoryLayout<Float>.size,
                    destination: raw.baseAddress! + offset * MemoryLayout<Float>.size
                )
            }
            guard status == kCMBlockBufferNoErr else { throw AudioExtractionError.unreadable(nil) }

            if expectedCount > 0 {
                let progress = min(1, Double(samples.count) / Double(expectedCount))
                if progress - lastReported >= 0.01 {
                    lastReported = progress
                    onProgress(progress)
                }
            }
        }

        if cancellation.isCancelled { throw CancelledError() }
        guard reader.status == .completed else { throw AudioExtractionError.unreadable(reader.error) }
        return samples
    }
}
