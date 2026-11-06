import XCTest

@testable import Stremio

final class TrackLanguageTests: XCTestCase {
    private func track(_ id: Int32, _ name: String, _ language: String? = nil) -> TrackLanguage.Track {
        TrackLanguage.Track(id: id, name: name, language: language)
    }

    func testStremioCodesMatchFileCodes() {
        XCTAssertTrue(TrackLanguage.matches(track(1, "Track 1", "en"), "eng"))
        XCTAssertTrue(TrackLanguage.matches(track(1, "Track 1", "fra"), "fre"))
        XCTAssertTrue(TrackLanguage.matches(track(1, "Track 1", "pt-BR"), "pob"))
        XCTAssertFalse(TrackLanguage.matches(track(1, "Track 1 - [English]", "ja"), "eng"))
    }

    func testFallsBackToTheTrackName() {
        XCTAssertTrue(TrackLanguage.matches(track(1, "Track 2 - [English]"), "eng"))
        XCTAssertFalse(TrackLanguage.matches(track(1, "Track 2 - [Japanese]"), "eng"))
    }

    func testPicksTheFirstPreferredLanguageThatExists() {
        let tracks = [track(1, "Track 1", "ja"), track(2, "Track 2", "en")]
        XCTAssertEqual(TrackLanguage.pick(tracks, preferred: ["spa", "eng"]), 2)
        XCTAssertEqual(TrackLanguage.pick(tracks, preferred: ["jpn", "eng"]), 1)
        XCTAssertNil(TrackLanguage.pick(tracks, preferred: ["spa"]))
        XCTAssertNil(TrackLanguage.pick(tracks, preferred: []))
    }

    func testPrefersAFullTrackOverForcedLines() {
        let tracks = [track(3, "English Forced - [English]", "en"), track(4, "English SDH - [English]", "en")]
        XCTAssertEqual(TrackLanguage.pick(tracks, preferred: ["eng"]), 4)
    }
}
