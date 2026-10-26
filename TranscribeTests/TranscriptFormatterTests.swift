import XCTest
@testable import Transcribe

final class TranscriptFormatterTests: XCTestCase {
    private let segments = [
        TranscriptSegment(start: 0, end: 2.5, text: " こんにちは。"),
        TranscriptSegment(start: 2.5, end: 3, text: "   "),
        TranscriptSegment(start: 754.32, end: 3725.009, text: "今日は晴れです。\n"),
    ]

    func testPlainTextHasOneLinePerSegmentAndSkipsBlanks() {
        XCTAssertEqual(TranscriptFormatter.plainText(segments), "こんにちは。\n今日は晴れです。\n")
    }

    func testTimestampedTextPrefixesStartTime() {
        XCTAssertEqual(
            TranscriptFormatter.timestampedText(segments),
            "[00:00:00] こんにちは。\n[00:12:34] 今日は晴れです。\n"
        )
    }

    func testSRT() {
        XCTAssertEqual(
            TranscriptFormatter.srt(segments),
            """
            1
            00:00:00,000 --> 00:00:02,500
            こんにちは。

            2
            00:12:34,320 --> 01:02:05,009
            今日は晴れです。

            """
        )
    }

    func testEmptyTranscript() {
        XCTAssertEqual(TranscriptFormatter.plainText([]), "")
        XCTAssertEqual(TranscriptFormatter.srt([]), "")
    }

    func testTimeFormatting() {
        XCTAssertEqual(TranscriptFormatter.clockTime(3599.99), "00:59:59")
        XCTAssertEqual(TranscriptFormatter.clockTime(7200), "02:00:00")
        XCTAssertEqual(TranscriptFormatter.srtTime(61.0006), "00:01:01,001")
        XCTAssertEqual(TranscriptFormatter.srtTime(-1), "00:00:00,000")
    }
}
