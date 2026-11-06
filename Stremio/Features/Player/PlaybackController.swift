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

    /// True from showing the player until its close animation ends.
    private var playerOnScreen = false
    private var pendingStream: Stream?

    func play(url: URL, title: String, startTime: Int = 0) {
        let next = Stream(url: url, title: title, startTime: startTime)
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
        guard let next = pendingStream else { return }
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
        session.playNext { started in
            if !started { close() }
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
