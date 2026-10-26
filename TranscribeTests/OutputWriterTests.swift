import XCTest
@testable import Transcribe

final class OutputWriterTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testFileNames() {
        let source = URL(fileURLWithPath: "/tmp/会議 2026.mov")
        XCTAssertTrue(OutputWriter.fileName(for: source, format: .plain) == ("会議 2026", "txt"))
        XCTAssertTrue(OutputWriter.fileName(for: source, format: .timestamps) == ("会議 2026_timestamps", "txt"))
        XCTAssertTrue(OutputWriter.fileName(for: source, format: .srt) == ("会議 2026", "srt"))
    }

    func testWritesAllFormatsWithoutOverwriting() throws {
        let source = URL(fileURLWithPath: "/tmp/talk.mp4")
        let segments = [TranscriptSegment(start: 1, end: 2, text: "hello")]

        let first = try OutputWriter.write(segments, sourceURL: source, formats: OutputFormat.allCases, to: folder)
        XCTAssertEqual(first.map(\.lastPathComponent), ["talk.txt", "talk_timestamps.txt", "talk.srt"])

        let second = try OutputWriter.write(segments, sourceURL: source, formats: OutputFormat.allCases, to: folder)
        XCTAssertEqual(second.map(\.lastPathComponent), ["talk_2.txt", "talk_timestamps_2.txt", "talk_2.srt"])

        let third = try OutputWriter.write(segments, sourceURL: source, formats: [.plain], to: folder)
        XCTAssertEqual(third.map(\.lastPathComponent), ["talk_3.txt"])

        XCTAssertEqual(try String(contentsOf: first[0], encoding: .utf8), "hello\n")
        XCTAssertEqual(try String(contentsOf: first[1], encoding: .utf8), "[00:00:01] hello\n")
    }

    func testCreatesMissingFolder() throws {
        let nested = folder.appendingPathComponent("a/b", isDirectory: true)
        let urls = try OutputWriter.write([], sourceURL: URL(fileURLWithPath: "/tmp/x.wav"), formats: [.srt], to: nested)
        XCTAssertTrue(FileManager.default.fileExists(atPath: urls[0].path))
    }
}
