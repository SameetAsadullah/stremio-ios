import XCTest

@testable import Stremio

final class MirrorURLTests: XCTestCase {
    func testRootPathMapsToMirror() {
        XCTAssertEqual(StreamProxy.mirrorURL(forTarget: "/")?.absoluteString, "https://web.stremio.com/")
    }

    func testPathAndQueryMapToMirror() {
        XCTAssertEqual(
            StreamProxy.mirrorURL(forTarget: "/scripts/main.js?v=1")?.absoluteString,
            "https://web.stremio.com/scripts/main.js?v=1")
    }

    func testAbsoluteTargetsAreRejected() {
        XCTAssertNil(StreamProxy.mirrorURL(forTarget: "https://evil.example/x"))
        XCTAssertNil(StreamProxy.mirrorURL(forTarget: "http://web.stremio.com/x"))
    }

    func testSchemeRelativeTargetsAreRejected() {
        XCTAssertNil(StreamProxy.mirrorURL(forTarget: "//evil.example/x"))
    }

    func testTargetsWithoutLeadingSlashAreRejected() {
        XCTAssertNil(StreamProxy.mirrorURL(forTarget: "x"))
        XCTAssertNil(StreamProxy.mirrorURL(forTarget: ""))
    }
}
