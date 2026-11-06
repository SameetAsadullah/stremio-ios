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
    /// Receives the player's progress, set by the web view model.
    var onProgress: ((ProgressEvent) -> Void)?

    func play(url: URL, title: String, startTime: Int = 0) {
        stream = Stream(url: url, title: title, startTime: startTime)
    }

    func report(_ event: ProgressEvent) {
        onProgress?(event)
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
