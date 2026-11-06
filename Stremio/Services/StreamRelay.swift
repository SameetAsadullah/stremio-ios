import Foundation
import Network

/// A client `Range: bytes=start-[end]` header. Other forms are treated as a request for the whole file.
struct ByteRange: Equatable {
    let start: Int64
    let end: Int64?

    static func parse(_ header: String?) -> ByteRange? {
        guard let header, header.hasPrefix("bytes=") else { return nil }
        let parts = header.dropFirst("bytes=".count).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let start = Int64(parts[0]), start >= 0 else { return nil }
        if parts[1].isEmpty { return ByteRange(start: start, end: nil) }
        guard let end = Int64(parts[1]), end >= start else { return nil }
        return ByteRange(start: start, end: end)
    }
}

/// An origin `Content-Range: bytes start-end/total` header.
struct ContentRange: Equatable {
    let start: Int64
    let end: Int64
    let total: Int64

    static func parse(_ header: String?) -> ContentRange? {
        guard let header, header.hasPrefix("bytes ") else { return nil }
        let parts = header.dropFirst("bytes ".count).split(separator: "/")
        guard parts.count == 2, let total = Int64(parts[1]) else { return nil }
        let bounds = parts[0].split(separator: "-")
        guard bounds.count == 2, let start = Int64(bounds[0]), let end = Int64(bounds[1]),
            start <= end, end < total
        else { return nil }
        return ContentRange(start: start, end: end, total: total)
    }
}

/// Relays one stream from the in-app server to VLC in fixed-size Range chunks.
///
/// The next chunk is requested only after VLC has taken the previous one, so memory stays at one
/// chunk however fast the server answers. URLSession has no such limit: once a torrent was mostly
/// cached, a single response pulled hundreds of megabytes into memory within a second and iOS
/// killed the app.
///
/// Cold torrents: the server cannot answer until it has the first pieces. VLC gives up after 3
/// tries, so the first chunk is retried while the client connection stays open. A chunk that fails
/// later is retried from the same offset, so a stalled torrent or a restarted server never reaches
/// VLC as an error.
final class StreamRelay: NSObject, URLSessionDataDelegate {
    static let chunkSize: Int64 = 4 << 20
    private static let startAttempts = 45
    private static let startRetryDelay: TimeInterval = 3
    private static let resumeAttempts = 60
    private static let resumeRetryDelay: TimeInterval = 2

    private let conn: NWConnection
    private let origin: URL
    private let isHead: Bool
    private let requested: ByteRange?
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    private var session: URLSession!

    // Touched only on `queue`.
    private var offset: Int64
    private var end: Int64?
    private var buffer = Data()
    private var oversized = false
    private var headWritten = false
    private var failures = 0
    private var finished = false

    init(conn: NWConnection, origin: URL, method: String, rangeHeader: String?) {
        self.conn = conn
        self.origin = origin
        self.isHead = method == "HEAD"
        self.requested = ByteRange.parse(rangeHeader)
        self.offset = requested?.start ?? 0
        self.end = requested?.end
        super.init()
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.urlCache = nil
        config.timeoutIntervalForRequest = 90
        session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }

    func start() {
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.queue.addOperation { self?.close() }
            default: break
            }
        }
        queue.addOperation { self.fetch() }
    }

    /// Last byte of the chunk that starts at `offset`, capped at `end` when it is known.
    static func chunkEnd(offset: Int64, end: Int64?, chunkSize: Int64 = chunkSize) -> Int64 {
        min(offset + chunkSize - 1, end ?? .max)
    }

    /// Response head for the client: 200 for a whole-file request, 206 for a Range request.
    static func responseHead(requested: ByteRange?, start: Int64, end: Int64, total: Int64, contentType: String?)
        -> String
    {
        var head: String
        if requested == nil {
            head = "HTTP/1.1 200 OK\r\nContent-Length: \(total)\r\n"
        } else {
            head = "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes \(start)-\(end)/\(total)\r\n"
            head += "Content-Length: \(end - start + 1)\r\n"
        }
        if let contentType { head += "Content-Type: \(contentType)\r\n" }
        return head + "Accept-Ranges: bytes\r\nConnection: close\r\n\r\n"
    }

    private func fetch() {
        guard !finished else { return }
        var request = URLRequest(url: origin)
        request.setValue("StremioApp/1.0", forHTTPHeaderField: "User-Agent")
        if isHead {
            request.httpMethod = "HEAD"
        } else {
            request.setValue(
                "bytes=\(offset)-\(Self.chunkEnd(offset: offset, end: end))", forHTTPHeaderField: "Range")
        }
        buffer.removeAll(keepingCapacity: true)
        oversized = false
        session.dataTask(with: request).resume()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        // An origin that ignores Range would send the whole file. Stop it at one chunk.
        if Int64(buffer.count) > Self.chunkSize {
            oversized = true
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !finished else { return }
        if oversized {
            fail(502, "Origin ignored the Range request")
            return
        }
        guard let http = task.response as? HTTPURLResponse, error == nil else {
            retry(reason: error?.localizedDescription ?? "no response")
            return
        }
        if isHead {
            relayHead(http)
            return
        }
        switch http.statusCode {
        case 206:
            deliver(http)
        case 502...504:
            retry(reason: "HTTP \(http.statusCode)")
        case 416 where !headWritten:
            fail(416, "Range Not Satisfiable")
        default:
            if headWritten {
                retry(reason: "HTTP \(http.statusCode), wanted 206")
            } else {
                fail(http.statusCode, "Origin error")
            }
        }
    }

    private func deliver(_ http: HTTPURLResponse) {
        guard let range = ContentRange.parse(http.value(forHTTPHeaderField: "Content-Range")),
            range.start == offset, !buffer.isEmpty
        else {
            retry(reason: "unexpected chunk \(http.value(forHTTPHeaderField: "Content-Range") ?? "-")")
            return
        }
        var payload = Data()
        if !headWritten {
            let last = min(end ?? range.total - 1, range.total - 1)
            end = last
            let head = Self.responseHead(
                requested: requested, start: offset, end: last, total: range.total,
                contentType: http.value(forHTTPHeaderField: "Content-Type"))
            payload.append(Data(head.utf8))
            headWritten = true
            Log.proxy.debug("stream \(self.offset)-\(last)/\(range.total) started")
        }
        payload.append(buffer)
        offset += Int64(buffer.count)
        failures = 0
        conn.send(
            content: payload,
            completion: .contentProcessed { [weak self] error in
                guard let self else { return }
                self.queue.addOperation {
                    if error != nil {
                        self.close()
                    } else if let end = self.end, self.offset > end {
                        self.finish()
                    } else {
                        self.fetch()
                    }
                }
            })
    }

    private func relayHead(_ http: HTTPURLResponse) {
        var head = "HTTP/1.1 \(http.statusCode) \(http.statusCode == 200 ? "OK" : "Status")\r\n"
        for key in ["Content-Type", "Content-Length", "Accept-Ranges"] {
            if let value = http.value(forHTTPHeaderField: key) { head += "\(key): \(value)\r\n" }
        }
        head += "Connection: close\r\n\r\n"
        conn.send(content: Data(head.utf8), completion: .contentProcessed { _ in })
        finish()
    }

    private func retry(reason: String) {
        failures += 1
        let limit = headWritten ? Self.resumeAttempts : Self.startAttempts
        guard failures <= limit else {
            if headWritten {
                Log.proxy.error("stream gave up at \(self.offset) after \(limit) tries (\(reason, privacy: .public))")
                finish()
            } else {
                fail(502, "Stream did not start")
            }
            return
        }
        let delay = headWritten ? Self.resumeRetryDelay : Self.startRetryDelay
        Log.proxy.info(
            "stream at \(self.offset) not ready (\(reason, privacy: .public)), retry \(self.failures)/\(limit) in \(delay)s"
        )
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.queue.addOperation { self?.fetch() }
        }
    }

    private func fail(_ status: Int, _ reason: String) {
        Log.proxy.error("stream failed: \(status) \(reason, privacy: .public)")
        let head = "HTTP/1.1 \(status) \(reason)\r\nConnection: close\r\nContent-Length: 0\r\n\r\n"
        conn.send(content: Data(head.utf8), completion: .contentProcessed { _ in })
        finish()
    }

    /// Ends the response after the last byte and closes the client connection.
    private func finish() {
        guard !finished else { return }
        finished = true
        conn.send(
            content: nil, contentContext: .finalMessage, isComplete: true,
            completion: .contentProcessed { [conn] _ in conn.cancel() })
        session.invalidateAndCancel()
    }

    /// The client went away, for example when VLC seeks and opens a new connection.
    private func close() {
        guard !finished else { return }
        finished = true
        conn.cancel()
        session.invalidateAndCancel()
    }
}
