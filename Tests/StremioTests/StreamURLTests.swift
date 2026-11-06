import XCTest

@testable import Stremio

final class StreamURLTests: XCTestCase {
    func testCleanedStreamURLStripsDanglingQuestionMark() {
        let url = URL(string: "http://127.0.0.1:11470/abc/0?")!
        XCTAssertEqual(WebViewModel.cleanedStreamURL(url).absoluteString, "http://127.0.0.1:11470/abc/0")
    }

    func testCleanedStreamURLKeepsRealQuery() {
        let url = URL(string: "http://127.0.0.1:11470/abc/0?tr=x")!
        XCTAssertEqual(WebViewModel.cleanedStreamURL(url), url)
    }

    func testCleanedStreamURLKeepsPlainURL() {
        let url = URL(string: "https://example.com/video.mkv")!
        XCTAssertEqual(WebViewModel.cleanedStreamURL(url), url)
    }

    func testStatsURLUsesInfoHashFromFirstPathComponent() {
        let hash = String(repeating: "a1", count: 20)
        let url = URL(string: "http://127.0.0.1:11470/\(hash)/3?tr=udp&x=1")!
        XCTAssertEqual(
            PlayerViewController.statsURL(for: url)?.absoluteString,
            "http://127.0.0.1:11470/\(hash)/stats.json")
    }

    func testStatsURLKeepsSchemeHostAndPort() {
        let hash = String(repeating: "b2", count: 20)
        let url = URL(string: "https://example.com:8443/\(hash)/0")!
        XCTAssertEqual(
            PlayerViewController.statsURL(for: url)?.absoluteString,
            "https://example.com:8443/\(hash)/stats.json")
    }

    func testStatsURLRejectsWrongHashLength() {
        let short = URL(string: "http://127.0.0.1:11470/\(String(repeating: "a", count: 39))/0")!
        let long = URL(string: "http://127.0.0.1:11470/\(String(repeating: "a", count: 41))/0")!
        XCTAssertNil(PlayerViewController.statsURL(for: short))
        XCTAssertNil(PlayerViewController.statsURL(for: long))
    }

    func testStatsURLRejectsURLWithoutPath() {
        XCTAssertNil(PlayerViewController.statsURL(for: URL(string: "http://127.0.0.1:11470")!))
        XCTAssertNil(PlayerViewController.statsURL(for: URL(string: "https://example.com/video.mkv")!))
    }
}
