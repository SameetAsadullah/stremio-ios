import SafariServices
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @ObservedObject var model: WebViewModel

    func makeCoordinator() -> Coordinator { Coordinator(model) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        // .default() is a persistent store, so the Stremio login survives app restarts.
        config.websiteDataStore = .default()

        let userScript = WKUserScript(
            source: UserScripts.source(named: "intercept"),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        // Pin Stremio Web's streaming server to the in-app one, even if the
        // account has a different server URL synced into its settings.
        config.userContentController.addUserScript(
            WKUserScript(
                source: UserScripts.source(named: "pin-local-server"),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true))
        // Weak proxy: userContentController retains the handler strongly, and the
        // coordinator retains the web view — a direct add() would leak both.
        config.userContentController.add(WeakScriptHandler(context.coordinator), name: "vlc")
        config.userContentController.add(WeakScriptHandler(context.coordinator), name: "bg")
        config.userContentController.addUserScript(
            WKUserScript(
                source: UserScripts.source(named: "background-color"),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true))

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = true
        webView.backgroundColor = UIColor(red: 0.055, green: 0.043, blue: 0.12, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor

        model.webView = webView
        webView.load(URLRequest(url: model.url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private let model: WebViewModel
        init(_ model: WebViewModel) { self.model = model }

        static func color(fromCSS css: String) -> UIColor? {
            let nums = css.replacingOccurrences(of: "rgba(", with: "")
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard nums.count >= 3, let r = Double(nums[0]), let g = Double(nums[1]), let b = Double(nums[2]) else {
                return nil
            }
            return UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
        }

        // MARK: navigation
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.isLoading = true
            model.errorMessage = nil
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.isLoading = false
            // The web app draws its first screen just after the load event.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.model.hasLoaded = true }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleFailure(error)
        }
        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
        ) {
            handleFailure(error)
        }
        private func handleFailure(_ error: Error) {
            model.isLoading = false
            if (error as NSError).code == NSURLErrorCancelled { return }
            model.errorMessage = error.localizedDescription
        }

        // MARK: new windows
        // Social logins, add-on configure pages and share links use window.open.
        // Facebook refuses logins in embedded web views, so show a Safari sheet.
        // The page polls Stremio's API until the login in the sheet completes.
        func webView(
            _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url,
                url.scheme == "https" || url.scheme == "http"
            else { return nil }
            var top = webView.window?.rootViewController
            while let next = top?.presentedViewController { top = next }
            Log.web.debug("new window \(url.absoluteString)")
            top?.present(SFSafariViewController(url: url), animated: true)
            return nil
        }

        // MARK: stream interception
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "bg", let css = message.body as? String, let color = Self.color(fromCSS: css) {
                DispatchQueue.main.async {
                    self.model.chromeColor = color
                    self.model.webView?.backgroundColor = color
                    self.model.webView?.scrollView.backgroundColor = color
                }
                return
            }
            guard message.name == "vlc",
                let body = message.body as? String,
                let data = body.data(using: .utf8),
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }
            if (obj["kind"] as? String) == "subtitles" {
                let items = (obj["items"] as? [[String: Any]] ?? []).compactMap {
                    d -> PlaybackController.ExternalSubtitle? in
                    guard let u = d["url"] as? String, let url = URL(string: u) else { return nil }
                    return PlaybackController.ExternalSubtitle(lang: d["lang"] as? String ?? "", url: url)
                }
                Log.web.debug("subtitle addon offered \(items.count) tracks")
                model.playback.addExternalSubtitles(items)
                return
            }
            guard let urlString = obj["url"] as? String, let url = URL(string: urlString) else { return }
            Log.web.debug("intercepted \(urlString)")
            let title = (obj["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Stream"
            model.play(url: url, title: title)
        }
    }
}
