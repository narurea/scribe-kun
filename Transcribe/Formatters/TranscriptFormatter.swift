import Foundation

/// One whisper segment. Times are in seconds from the start of the media.
struct TranscriptSegment: Equatable, Sendable {
    var start: TimeInterval
    var end: TimeInterval
    var text: String
}

enum TranscriptFormatter {
    static func format(_ segments: [TranscriptSegment], as format: OutputFormat) -> String {
        switch format {
        case .plain: plainText(segments)
        case .timestamps: timestampedText(segments)
        case .srt: srt(segments)
        }
    }

    /// One line per segment.
    static func plainText(_ segments: [TranscriptSegment]) -> String {
        lines(cleaned(segments).map(\.text))
    }

    /// One line per segment, prefixed with the start time: `[00:12:34] text`.
    static func timestampedText(_ segments: [TranscriptSegment]) -> String {
        lines(cleaned(segments).map { "[\(clockTime($0.start))] \($0.text)" })
    }

    /// SubRip subtitles.
    static func srt(_ segments: [TranscriptSegment]) -> String {
        cleaned(segments).enumerated().map { index, segment in
            "\(index + 1)\n\(srtTime(segment.start)) --> \(srtTime(max(segment.end, segment.start)))\n\(segment.text)\n"
        }
        .joined(separator: "\n")
    }

    /// `HH:MM:SS`, truncated to whole seconds.
    static func clockTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }

    /// `HH:MM:SS,mmm`
    static func srtTime(_ seconds: TimeInterval) -> String {
        let millis = Int((max(0, seconds) * 1000).rounded())
        let total = millis / 1000
        return String(format: "%02d:%02d:%02d,%03d", total / 3600, total / 60 % 60, total % 60, millis % 1000)
    }

    private static func cleaned(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        segments.compactMap { segment in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return TranscriptSegment(start: segment.start, end: segment.end, text: text)
        }
    }

    private static func lines(_ lines: [String]) -> String {
        lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }
}
