import XCTest

@testable import Stremio

final class SubtitleSizeTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "SubtitleSizeTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testDefaultsToNormal() {
        XCTAssertEqual(SubtitleSize.saved(in: defaults), .normal)
    }

    func testUnknownStoredValueFallsBackToNormal() {
        defaults.set(3, forKey: SubtitleSize.defaultsKey)
        XCTAssertEqual(SubtitleSize.saved(in: defaults), .normal)
    }

    func testSavedSizeIsRestored() {
        SubtitleSize.large.save(in: defaults)
        XCTAssertEqual(SubtitleSize.saved(in: defaults), .large)
    }

    func testLargerSizesUseSmallerDivisors() {
        let divisors = SubtitleSize.allCases.map(\.rawValue)
        XCTAssertEqual(divisors, divisors.sorted(by: >))
    }
}
