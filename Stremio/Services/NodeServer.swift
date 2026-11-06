import CryptoKit
import Foundation

/// Runs Stremio's streaming server (server.js) *inside the app* via nodejs-mobile,
/// on http://127.0.0.1:11470 — so torrents stream on-device with no external
/// server. Mirrors what Stremio's own mobile build does: HTTPS side and the
/// ffmpeg HLS transcoder are disabled (no child processes on iOS); VLC plays the
/// raw file the server serves.
final class NodeServer: ObservableObject {
    static let shared = NodeServer()
    static let port = 11470
    static var baseURL: URL { URL(string: "http://127.0.0.1:\(port)")! }

    @Published private(set) var isReady = false
    @Published private(set) var status = "Not started"
    private(set) var started = false
    private var thread: Thread?
    private var readyTimer: Timer?

    static var cachesDir: String {
        NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
    }
    static var logPath: String { (cachesDir as NSString).appendingPathComponent("stremio-server.log") }

    func startIfNeeded() {
        guard !started else { return }
        guard let serverJS = ServerScript.localPath() else {
            status = "Streaming engine not downloaded"
            return
        }
        started = true
        status = "Starting\u{2026}"
        let t = Thread { Self.run(serverJS) }
        t.name = "stremio-server"
        t.stackSize = 8 << 20
        thread = t
        t.start()
        pollReady()
    }

    private func pollReady() {
        readyTimer?.invalidate()
        var attempts = 0
        readyTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            attempts += 1
            var req = URLRequest(url: Self.baseURL.appendingPathComponent("settings"))
            req.timeoutInterval = 2
            URLSession.shared.dataTask(with: req) { data, resp, _ in
                let ok = (resp as? HTTPURLResponse)?.statusCode == 200 && data != nil
                DispatchQueue.main.async {
                    if ok {
                        self.isReady = true
                        self.status = "Running on 127.0.0.1:\(Self.port)"
                        Log.server.info("server ready after \(attempts)s")
                        timer.invalidate()
                    } else if attempts > 60 {
                        self.status = "Didn\u{2019}t start \u{2014} see log"
                        Log.server.error("not ready after 60s; log tail:\n\(Self.logTail(30), privacy: .public)")
                        timer.invalidate()
                    }
                }
            }.resume()
        }
    }

    static func logTail(_ lines: Int) -> String {
        guard let s = try? String(contentsOfFile: logPath, encoding: .utf8) else { return "(no log)" }
        return s.split(separator: "\n").suffix(lines).joined(separator: "\n")
    }

    private static func run(_ serverJS: String) {
        let caches = cachesDir
        let data = (caches as NSString).appendingPathComponent("stremio-server")
        try? FileManager.default.createDirectory(atPath: data, withIntermediateDirectories: true)

        // Torrent engines open many sockets/files; the default 256 is far too low.
        var lim = rlimit()
        if getrlimit(RLIMIT_NOFILE, &lim) == 0 {
            lim.rlim_cur = min(rlim_t(OPEN_MAX), lim.rlim_max)
            setrlimit(RLIMIT_NOFILE, &lim)
        }

        setenv("HOME", caches, 1)
        setenv("APP_PATH", data, 1)          // engine cache lives under Caches (purgeable)
        setenv("NO_CORS", "1", 1)
        setenv("CASTING_DISABLED", "1", 1)
        setenv("NO_HTTPS_SERVER", "1", 1)    // no cert fetch / :12470 on iOS
        setenv("HLS_V2_DISABLED", "1", 1)    // transcoder shells out to ffmpeg — impossible here
        setenv("UV_THREADPOOL_SIZE", "16", 1)
        FileManager.default.changeCurrentDirectoryPath(caches)

        // Preload: route console output to a file we can read from Swift/`log show`.
        // server.js listens on all interfaces, which exposes it to everyone on the Wi-Fi.
        // Pin its HTTP ports (11470, with fallbacks to 11474) to loopback. Peer ports stay open.
        guard let preloadPath = UserScripts.url(named: "node-preload")?.path else {
            assertionFailure("Missing bundled script node-preload.js")
            return
        }
        setenv("STREMIO_LOG_PATH", logPath, 1)
        try? "===== BOOT =====\n".write(toFile: logPath, atomically: true, encoding: .utf8)

        Log.server.info("starting \(serverJS, privacy: .public)")
        let args = ["node", "-r", preloadPath, serverJS]
        var cargs: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        let code = cargs.withUnsafeMutableBufferPointer { node_start(Int32(args.count), $0.baseAddress) }
        cargs.forEach { free($0) }
        Log.server.error("exited with code \(code)")
    }
}

/// Stremio's `server.js` is Stremio's own file, distributed freely inside their
/// apps. We don't ship it in the repo; the app downloads it once from Stremio's
/// CDN into Application Support (a bundled copy is used if present).
enum ServerScript {
    static let version = "v4.21.1"
    /// SHA-256 of the official v4.21.1 file. Change it together with `version`.
    static let sha256 = "405eb494d6708406a30e716c3cfb5abae7a5e9c7a8b79446d64c3f821385930f"
    static var downloadURL: URL { URL(string: "https://dl.strem.io/server/\(version)/desktop/server.js")! }

    static var downloadedPath: String {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("stremio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("server.js").path
    }

    static func localPath() -> String? {
        if isValid(downloadedPath) { return downloadedPath }
        try? FileManager.default.removeItem(atPath: downloadedPath)
        if let bundled = Bundle.main.path(forResource: "server", ofType: "js"), isValid(bundled) { return bundled }
        return nil
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func isValid(_ path: String, expectedSHA256: String = sha256) -> Bool {
        guard let data = FileManager.default.contents(atPath: path) else { return false }
        return sha256Hex(of: data) == expectedSHA256
    }

    /// Downloads if missing. Completion on main.
    static func ensure(progress: @escaping (String) -> Void, completion: @escaping (Bool) -> Void) {
        if localPath() != nil { completion(true); return }
        progress("Downloading streaming engine\u{2026}")
        let task = URLSession.shared.downloadTask(with: downloadURL) { tmp, resp, err in
            var ok = false
            if let tmp, (resp as? HTTPURLResponse)?.statusCode == 200 {
                try? FileManager.default.removeItem(atPath: downloadedPath)
                ok = (try? FileManager.default.moveItem(atPath: tmp.path, toPath: downloadedPath)) != nil
                    && isValid(downloadedPath)
                if !ok { try? FileManager.default.removeItem(atPath: downloadedPath) }
            }
            if ok { Log.server.info("server.js download ok") } else {
                Log.server.error("server.js download FAILED \(err?.localizedDescription ?? "", privacy: .public)")
            }
            DispatchQueue.main.async { completion(ok) }
        }
        task.resume()
    }
}
