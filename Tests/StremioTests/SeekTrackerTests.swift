import XCTest

@testable import Stremio

final class SeekTrackerTests: XCTestCase {
    func testJumpStartsFromPendingTarget() {
        var seek = SeekTracker()
        seek.seek(to: 1_800_000)
        // VLC still reports 5:00 while it buffers 30:00. +10 s must go to 30:10, not 5:10.
        XCTAssertEqual(seek.jump(from: 300_000, by: 10_000, duration: 3_600_000), 1_810_000)
    }

    func testJumpWithoutTargetUsesCurrentTime() {
        XCTAssertEqual(SeekTracker().jump(from: 300_000, by: -10_000, duration: 3_600_000), 290_000)
    }

    func testJumpStaysInsideVideo() {
        let seek = SeekTracker()
        XCTAssertEqual(seek.jump(from: 4000, by: -10_000, duration: 3_600_000), 0)
        XCTAssertEqual(seek.jump(from: 3_595_000, by: 10_000, duration: 3_600_000), 3_599_000)
    }

    func testStaleTimeDoesNotEndTheSeek() {
        var seek = SeekTracker()
        let start = Date()
        seek.seek(to: 1_800_000, now: start)
        XCTAssertEqual(seek.update(time: 300_000, now: start.addingTimeInterval(1)), .none)
        XCTAssertEqual(seek.target, 1_800_000)
    }

    func testReachingTheTargetEndsTheSeek() {
        var seek = SeekTracker()
        seek.seek(to: 1_800_000)
        XCTAssertEqual(seek.update(time: 1_801_200), .reached)
        XCTAssertNil(seek.target)
    }

    func testDroppedSeekIsReissuedThenGivenUp() {
        var seek = SeekTracker()
        let start = Date()
        seek.seek(to: 1_800_000, now: start)
        XCTAssertEqual(seek.update(time: 300_000, now: start.addingTimeInterval(5)), .reissue(1_800_000))
        XCTAssertEqual(seek.update(time: 304_000, now: start.addingTimeInterval(10)), .reissue(1_800_000))
        XCTAssertEqual(seek.update(time: 308_000, now: start.addingTimeInterval(15)), .gaveUp)
        XCTAssertNil(seek.target)
    }

    func testClock() {
        XCTAssertEqual(SeekTracker.clock(245_000), "04:05")
        XCTAssertEqual(SeekTracker.clock(3_725_000), "1:02:05")
        XCTAssertEqual(SeekTracker.clock(-5), "00:00")
    }
}
