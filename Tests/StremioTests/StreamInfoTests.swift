import XCTest

@testable import Stremio

final class StreamInfoTests: XCTestCase {
    func testParsesEpisodeWithNextVideo() {
        let info = StreamInfo([
            "name": "Severance",
            "poster": "https://images.example.com/poster.jpg",
            "episode": "S1E4 · The You You Are",
            "next": ["label": "S1E5 · The Grim Barbarity", "thumbnail": "https://images.example.com/5.jpg"],
            "bingeWatching": false,
            "notifyMs": 20_000,
        ])
        XCTAssertEqual(info?.name, "Severance")
        XCTAssertEqual(info?.poster, URL(string: "https://images.example.com/poster.jpg"))
        XCTAssertEqual(info?.episode, "S1E4 · The You You Are")
        XCTAssertEqual(info?.next?.label, "S1E5 · The Grim Barbarity")
        XCTAssertEqual(info?.bingeWatching, false)
        XCTAssertEqual(info?.notifyMs, 20_000)
    }

    func testUsesStremioDefaultsForMissingSettings() {
        let info = StreamInfo(["name": "A Movie", "next": NSNull()])
        XCTAssertNil(info?.next)
        XCTAssertEqual(info?.bingeWatching, true)
        XCTAssertEqual(info?.notifyMs, 35_000)
    }

    func testParsesPreferredLanguages() {
        let info = StreamInfo(["audioLanguages": ["jpn", "eng"], "subtitleLanguages": ["eng"]])
        XCTAssertEqual(info?.audioLanguages, ["jpn", "eng"])
        XCTAssertEqual(info?.subtitleLanguages, ["eng"])
        XCTAssertEqual(StreamInfo([:])?.subtitleLanguages, [])
    }

    func testDropsNonHTTPSImages() {
        let info = StreamInfo(["poster": "http://images.example.com/poster.jpg"])
        XCTAssertNil(info?.poster)
    }

    func testRejectsNonObjects() {
        XCTAssertNil(StreamInfo(nil))
        XCTAssertNil(StreamInfo(NSNull()))
    }
}

final class NextEpisodeLeadTests: XCTestCase {
    private let info = StreamInfo()

    func testLongEpisodeIsCappedAtTwoMinutes() {
        XCTAssertEqual(info.nextEpisodeLead(duration: 45 * 60_000), 120_000)
    }

    func testShortEpisodeUsesTenPercent() {
        XCTAssertEqual(info.nextEpisodeLead(duration: 10 * 60_000), 60_000)
    }

    func testNeverShorterThanStremioSetting() {
        XCTAssertEqual(info.nextEpisodeLead(duration: 5 * 60_000), 35_000)
        var long = StreamInfo()
        long.notifyMs = 180_000
        XCTAssertEqual(long.nextEpisodeLead(duration: 45 * 60_000), 180_000)
    }
}
