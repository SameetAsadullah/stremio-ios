import Combine
import SwiftUI

/// Holds the stream currently requested for native playback. When `stream` is
/// set, ContentView presents the VLC player over the web UI.
final class PlaybackController: ObservableObject {
    struct Stream: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let title: String
    }

    struct ExternalSubtitle: Identifiable, Equatable {
        var id: String { url.absoluteString }
        let lang: String
        let url: URL
    }

    @Published var stream: Stream?
    /// Subtitles offered by Stremio's subtitle addons for the current item.
    @Published var externalSubtitles: [ExternalSubtitle] = []

    func play(url: URL, title: String) {
        stream = Stream(url: url, title: title)
    }

    func addExternalSubtitles(_ items: [ExternalSubtitle]) {
        for item in items where !externalSubtitles.contains(item) { externalSubtitles.append(item) }
    }

    func stop() {
        NSLog("[STREMIOAPP] PlaybackController.stop() — dismissing player")
        stream = nil; externalSubtitles = []
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
