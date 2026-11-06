import Foundation

/// What Stremio's core knows about the playing item, read through `intercept.js`.
struct StreamInfo: Equatable {
    struct NextVideo: Equatable {
        let label: String
        let thumbnail: URL?
    }

    var name: String?
    var poster: URL?
    /// "S1E4 · Title" for an episode, nil for a movie.
    var episode: String?
    var next: NextVideo?
    /// Stremio's "binge watching" setting: play the next episode when one ends.
    var bingeWatching = true
    /// How long before the end Stremio offers the next episode, in milliseconds.
    var notifyMs = 35_000

    /// How long before the end to offer the next episode. Stremio treats the last 10% as credits;
    /// capped at 2 minutes so long episodes do not show it too early. Stremio's own setting wins
    /// when it is longer.
    func nextEpisodeLead(duration: Int) -> Int {
        max(notifyMs, min(duration / 10, 120_000))
    }

    init(name: String? = nil, poster: URL? = nil, episode: String? = nil, next: NextVideo? = nil) {
        self.name = name
        self.poster = poster
        self.episode = episode
        self.next = next
    }

    init?(_ object: Any?) {
        guard let dict = object as? [String: Any] else { return nil }
        name = dict["name"] as? String
        poster = (dict["poster"] as? String).flatMap(Self.httpsURL)
        episode = dict["episode"] as? String
        if let next = dict["next"] as? [String: Any] {
            self.next = NextVideo(
                label: next["label"] as? String ?? "Next episode",
                thumbnail: (next["thumbnail"] as? String).flatMap(Self.httpsURL))
        }
        if let binge = dict["bingeWatching"] as? Bool { bingeWatching = binge }
        if let ms = (dict["notifyMs"] as? NSNumber)?.intValue, ms > 0 { notifyMs = ms }
    }

    /// Native requests must use HTTPS.
    private static func httpsURL(_ string: String) -> URL? {
        guard let url = URL(string: string), url.scheme == "https" else { return nil }
        return url
    }
}

/// What the player needs from Stremio's web app.
protocol StremioSession: AnyObject {
    func report(_ event: PlaybackController.ProgressEvent)
    func streamInfo(_ completion: @escaping (StreamInfo?) -> Void)
    /// Starts the next episode the way Stremio's player does. The completion gets false when
    /// there is no next episode to go to.
    func playNext(_ completion: @escaping (Bool) -> Void)
}
