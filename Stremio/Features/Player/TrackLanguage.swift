import Foundation

/// Matches VLC tracks and add-on subtitles to the languages in Stremio's settings.
enum TrackLanguage {
    struct Track: Equatable {
        let id: Int32
        let name: String
        /// The code the file gives for the track, when it has one.
        let language: String?
    }

    private static let english = Locale(identifier: "en")

    /// Stremio uses ISO 639-2 codes ("eng", "fre"), files and add-ons also use "en" or "en-US".
    /// The English name of the language is the same for all of them.
    static func key(_ code: String) -> String {
        var c = code.trimmingCharacters(in: .whitespaces).lowercased()
        // OpenSubtitles' code for Brazilian Portuguese.
        if c == "pob" { c = "pt" }
        return english.localizedString(forLanguageCode: c)?.lowercased() ?? c
    }

    static func matches(_ track: Track, _ preferred: String) -> Bool {
        let want = key(preferred)
        if let language = track.language, !language.isEmpty { return key(language) == want }
        // Without a code, VLC names the track like "Track 2 - [English]".
        return track.name.lowercased().contains(want)
    }

    /// The first track in the first preferred language that has one. Forced tracks hold only
    /// the foreign lines, so a full track wins.
    static func pick(_ tracks: [Track], preferred: [String]) -> Int32? {
        for language in preferred {
            let found = tracks.filter { matches($0, language) }
            if let track = found.first(where: { !$0.name.lowercased().contains("forced") }) ?? found.first {
                return track.id
            }
        }
        return nil
    }
}
