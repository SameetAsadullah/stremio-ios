import SwiftUI
import WebKit

/// Owns the WKWebView-driven state so SwiftUI can show loading/error chrome
/// without the web view being torn down on every state change.
final class WebViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var errorMessage: String?
    /// Background colour reported by the page, used to tint the safe-area chrome.
    @Published var chromeColor: UIColor = UIColor(red: 0.055, green: 0.043, blue: 0.12, alpha: 1) // Stremio navy

    let url: URL
    let playback: PlaybackController
    weak var webView: WKWebView?

    init(url: URL, playback: PlaybackController) {
        self.url = url
        self.playback = playback
    }

    func reload() {
        errorMessage = nil
        isLoading = true
        webView?.load(URLRequest(url: url))
    }

    /// Hands the stream to VLC. Shared by the page interception and the self-test.
    func play(url rawURL: URL, title: String) {
        // Stremio's URL builder leaves a dangling '?'; libvlc's HTTP access can
        // mis-handle an empty query, so strip it.
        var s = rawURL.absoluteString
        if s.hasSuffix("?") { s.removeLast() }
        let url = URL(string: s) ?? rawURL
        if playback.stream?.url == url { return }
        playback.play(url: url, title: title)
    }
}
