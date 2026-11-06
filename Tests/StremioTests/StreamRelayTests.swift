import XCTest

@testable import Stremio

final class StreamRelayTests: XCTestCase {
    func testParsesOpenEndedRange() {
        XCTAssertEqual(ByteRange.parse("bytes=124-"), ByteRange(start: 124, end: nil))
    }

    func testParsesClosedRange() {
        XCTAssertEqual(ByteRange.parse("bytes=0-1023"), ByteRange(start: 0, end: 1023))
    }

    func testRejectsUnsupportedRanges() {
        XCTAssertNil(ByteRange.parse(nil))
        XCTAssertNil(ByteRange.parse("bytes=-500"))
        XCTAssertNil(ByteRange.parse("bytes=0-10,20-30"))
        XCTAssertNil(ByteRange.parse("bytes=10-5"))
        XCTAssertNil(ByteRange.parse("items=0-10"))
    }

    func testParsesContentRange() {
        XCTAssertEqual(
            ContentRange.parse("bytes 4194304-8388607/4113000000"),
            ContentRange(start: 4_194_304, end: 8_388_607, total: 4_113_000_000))
    }

    func testRejectsInvalidContentRange() {
        XCTAssertNil(ContentRange.parse(nil))
        XCTAssertNil(ContentRange.parse("bytes 0-99/*"))
        XCTAssertNil(ContentRange.parse("bytes 0-100/100"))
        XCTAssertNil(ContentRange.parse("bytes */100"))
    }

    func testChunkEndUsesChunkSize() {
        XCTAssertEqual(StreamRelay.chunkEnd(offset: 0, end: nil, chunkSize: 100), 99)
        XCTAssertEqual(StreamRelay.chunkEnd(offset: 250, end: nil, chunkSize: 100), 349)
    }

    func testChunkEndStopsAtRangeEnd() {
        XCTAssertEqual(StreamRelay.chunkEnd(offset: 250, end: 300, chunkSize: 100), 300)
    }

    func testWholeFileHeadIs200() {
        let head = StreamRelay.responseHead(
            requested: nil, start: 0, end: 999, total: 1000, contentType: "video/x-matroska")
        XCTAssertTrue(head.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(head.contains("Content-Length: 1000\r\n"))
        XCTAssertTrue(head.contains("Content-Type: video/x-matroska\r\n"))
        XCTAssertFalse(head.contains("Content-Range"))
        XCTAssertTrue(head.hasSuffix("\r\n\r\n"))
    }

    func testRangeHeadIs206() {
        let head = StreamRelay.responseHead(
            requested: ByteRange(start: 124, end: nil), start: 124, end: 999, total: 1000, contentType: nil)
        XCTAssertTrue(head.hasPrefix("HTTP/1.1 206 Partial Content\r\n"))
        XCTAssertTrue(head.contains("Content-Range: bytes 124-999/1000\r\n"))
        XCTAssertTrue(head.contains("Content-Length: 876\r\n"))
    }
}
