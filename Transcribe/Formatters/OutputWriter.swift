import Foundation

/// Writes transcripts next to each other in the output folder without ever overwriting.
enum OutputWriter {
    /// File name stem and extension for a source file, e.g. `talk` + `.txt` / `talk_timestamps` + `.txt`.
    static func fileName(for sourceURL: URL, format: OutputFormat) -> (stem: String, ext: String) {
        let base = sourceURL.deletingPathExtension().lastPathComponent
        switch format {
        case .plain: return (base, "txt")
        case .timestamps: return ("\(base)_timestamps", "txt")
        case .srt: return (base, "srt")
        }
    }

    /// `stem.ext`, or `stem_2.ext`, `stem_3.ext`, … if that name is taken.
    static func uniqueURL(in folder: URL, stem: String, ext: String, fileManager: FileManager = .default) -> URL {
        var candidate = folder.appendingPathComponent("\(stem).\(ext)")
        var number = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(stem)_\(number).\(ext)")
            number += 1
        }
        return candidate
    }

    /// Writes one file per format and returns their URLs.
    static func write(
        _ segments: [TranscriptSegment],
        sourceURL: URL,
        formats: [OutputFormat],
        to folder: URL,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return try formats.map { format in
            let name = fileName(for: sourceURL, format: format)
            let url = uniqueURL(in: folder, stem: name.stem, ext: name.ext, fileManager: fileManager)
            let text = TranscriptFormatter.format(segments, as: format)
            try Data(text.utf8).write(to: url, options: .withoutOverwriting)
            return url
        }
    }
}
