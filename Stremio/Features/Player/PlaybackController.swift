import Combine
import SwiftUI

/// Holds the stream currently requested for native playback. When `stream` is
/// set, ContentView presents the VLC player over the web UI.
final class PlaybackController: ObservableObject {
    struct Stream: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let title: String
        /// Saved position to resume from, in milliseconds.
        var startTime = 0
    }

    /// Playback events that Stremio records as watch progress. Times are in milliseconds.
    enum ProgressEvent: Equatable {
        case time(Int, duration: Int)
        case seek(Int, duration: Int)
        case paused(Bool)
        case ended
    }

    struct ExternalSubtitle: Identifiable, Equatable {
        var id: String { url.absoluteString }
        let lang: String
        let url: URL
    }

    @Published var stream: Stream?
    /// Subtitles offered by Stremio's subtitle addons for the current item.
    @Published var externalSubtitles: [ExternalSubtitle] = []
    weak var session: StremioSession?
    let orientation = PlayerOrientation()

    /// True from showing the player until its close animation ends.
    private var playerOnScreen = false
    private var pendingStream: Stream?
    /// True from Next Episode until the next stream arrives.
    private var awaitingNextEpisode = false

    func play(url: URL, title: String, startTime: Int = 0) {
        let next = Stream(url: url, title: title, startTime: startTime)
        awaitingNextEpisode = false
        // iOS ignores a new full-screen player while the old one is still closing, which happens
        // when the next episode's stream arrives quickly. Show it once the close has finished.
        if stream == nil && playerOnScreen {
            Log.player.info("player still closing, holding the next stream")
            pendingStream = next
            return
        }
        stream = next
        playerOnScreen = true
    }

    func playerDidClose() {
        playerOnScreen = false
        guard let next = pendingStream else {
            // Rotating only after the slide-down ends keeps the two animations apart, and iOS
            // drops orientation requests made during it.
            if awaitingNextEpisode { orientation.restoreUnlessPlayerOpens() } else { orientation.restore() }
            return
        }
        pendingStream = nil
        stream = next
        playerOnScreen = true
    }

    func report(_ event: ProgressEvent) {
        session?.report(event)
    }

    func streamInfo(_ completion: @escaping (StreamInfo?) -> Void) {
        guard let session else { return completion(nil) }
        session.streamInfo(completion)
    }

    /// Closes the player and lets the web app open the next episode. The web app then sends the
    /// next stream, as for a normal Play.
    func playNext(orElse close: @escaping () -> Void) {
        guard let session else { return close() }
        stop()
        awaitingNextEpisode = true
        session.playNext { started in
            guard !started else { return }
            self.awaitingNextEpisode = false
            // While the player is still sliding away, playerDidClose rotates back.
            if !self.playerOnScreen { self.orientation.restore() }
            close()
        }
    }

    func addExternalSubtitles(_ items: [ExternalSubtitle]) {
        for item in items where !externalSubtitles.contains(item) { externalSubtitles.append(item) }
    }

    func stop() {
        Log.player.debug("PlaybackController.stop() — dismissing player")
        stream = nil
        externalSubtitles = []
    }
}

struct VLCPlayerContainer: UIViewControllerRepresentable {
    let stream: PlaybackController.Stream
    let playback: PlaybackController
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> PlayerViewController {
        PlayerViewController(stream: stream, playback: playback, onClose: onClose)
    }

    func updateUIViewController(_ uiViewController: PlayerViewController, context: Context) {}
}
