import SwiftUI
import WebKit

/// Owns the WKWebView-driven state so SwiftUI can show loading/error chrome
/// without the web view being torn down on every state change.
final class WebViewModel: ObservableObject {
    @Published var isLoading = true
    /// False until the first page load, while the splash screen shows.
    @Published var hasLoaded = false
    @Published var errorMessage: String?
    /// Background colour reported by the page, used to tint the safe-area chrome.
    @Published var chromeColor: UIColor = UIColor(red: 0.055, green: 0.043, blue: 0.12, alpha: 1)  // Stremio navy

    let url: URL
    let playback: PlaybackController
    weak var webView: WKWebView?

    init(url: URL, playback: PlaybackController) {
        self.url = url
        self.playback = playback
        playback.onProgress = { [weak self] in self?.sendProgress($0) }
    }

    /// Passes the player's progress to Stremio's core through `intercept.js`.
    private func sendProgress(_ event: PlaybackController.ProgressEvent) {
        let call: String
        switch event {
        case .time(let time, let duration): call = "time(\(time), \(duration))"
        case .seek(let time, let duration): call = "seek(\(time), \(duration))"
        case .paused(let paused): call = "paused(\(paused))"
        case .ended: call = "ended()"
        }
        webView?.evaluateJavaScript("window.__stremioVLC && window.__stremioVLC.\(call)")
    }

    func reload() {
        errorMessage = nil
        isLoading = true
        webView?.load(URLRequest(url: url))
    }

    /// Stremio's web player stays open behind VLC with a failed video, so return to the page the
    /// user pressed Play on.
    func leavePlayerPage() {
        guard let webView, webView.url?.fragment?.hasPrefix("/player/") == true else { return }
        Log.web.debug("leaving the web player page")
        webView.evaluateJavaScript("history.back()")
    }

    /// Stremio's URL builder leaves a dangling '?'; libvlc's HTTP access can
    /// mis-handle an empty query, so strip it.
    static func cleanedStreamURL(_ rawURL: URL) -> URL {
        var s = rawURL.absoluteString
        if s.hasSuffix("?") { s.removeLast() }
        return URL(string: s) ?? rawURL
    }

    /// Hands the stream to VLC. Shared by the page interception and the self-test.
    func play(url rawURL: URL, title: String, startTime: Int = 0) {
        let url = Self.cleanedStreamURL(rawURL)
        if playback.stream?.url == url { return }
        playback.play(url: url, title: title, startTime: startTime)
    }
}
