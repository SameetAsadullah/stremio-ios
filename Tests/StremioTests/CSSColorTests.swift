import UIKit
import XCTest

@testable import Stremio

final class CSSColorTests: XCTestCase {
    private func components(_ color: UIColor?) -> [CGFloat]? {
        guard let color else { return nil }
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }

    func testParsesRGB() throws {
        let c = try XCTUnwrap(components(WebView.Coordinator.color(fromCSS: "rgb(14, 11, 31)")))
        XCTAssertEqual(c[0], 14.0 / 255, accuracy: 0.001)
        XCTAssertEqual(c[1], 11.0 / 255, accuracy: 0.001)
        XCTAssertEqual(c[2], 31.0 / 255, accuracy: 0.001)
        XCTAssertEqual(c[3], 1, accuracy: 0.001)
    }

    func testParsesRGBAAndIgnoresAlpha() throws {
        let c = try XCTUnwrap(components(WebView.Coordinator.color(fromCSS: "rgba(255, 0, 128, 0.5)")))
        XCTAssertEqual(c[0], 1, accuracy: 0.001)
        XCTAssertEqual(c[1], 0, accuracy: 0.001)
        XCTAssertEqual(c[2], 128.0 / 255, accuracy: 0.001)
        XCTAssertEqual(c[3], 1, accuracy: 0.001)
    }

    func testRejectsJunk() {
        XCTAssertNil(WebView.Coordinator.color(fromCSS: ""))
        XCTAssertNil(WebView.Coordinator.color(fromCSS: "transparent"))
        XCTAssertNil(WebView.Coordinator.color(fromCSS: "rgb(1, 2)"))
        XCTAssertNil(WebView.Coordinator.color(fromCSS: "rgb(a, b, c)"))
    }
}
