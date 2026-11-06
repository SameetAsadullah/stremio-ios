import Network
import XCTest

@testable import Stremio

/// A slow torrent: the origin sends the first bytes of a chunk and then stalls. VLC must get those
/// bytes at once, not after the whole chunk.
final class StreamRelayStreamingTests: XCTestCase {
    private var listeners: [NWListener] = []
    private var connections: [NWConnection] = []
    private var relays: [StreamRelay] = []

    override func tearDown() {
        for listener in listeners { listener.cancel() }
        for connection in connections { connection.cancel() }
        super.tearDown()
    }

    func testRelaysBytesBeforeTheChunkIsComplete() throws {
        let first = Data(repeating: 7, count: 1000)
        let originPort = try listen { conn in
            conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { _, _, _, _ in
                let head =
                    "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes 0-99999/100000\r\n"
                    + "Content-Length: 100000\r\nContent-Type: video/mp4\r\n\r\n"
                conn.send(content: Data(head.utf8) + first, completion: .idempotent)
                // The rest never comes during the test.
            }
        }
        let origin = URL(string: "http://127.0.0.1:\(originPort)/file")!
        let proxyPort = try listen { [weak self] conn in
            let relay = StreamRelay(conn: conn, origin: origin, method: "GET", rangeHeader: "bytes=0-")
            self?.relays.append(relay)
            relay.start()
        }

        let client = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: proxyPort)!, using: .tcp)
        connections.append(client)
        let received = expectation(description: "first bytes relayed")
        var data = Data()
        func read() {
            client.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { chunk, _, _, error in
                if let chunk { data.append(chunk) }
                if let end = data.range(of: Data("\r\n\r\n".utf8)), data.count - end.upperBound >= first.count {
                    received.fulfill()
                } else if error == nil {
                    read()
                }
            }
        }
        client.start(queue: .global())
        client.send(content: Data("GET /file HTTP/1.1\r\nRange: bytes=0-\r\n\r\n".utf8), completion: .idempotent)
        read()

        wait(for: [received], timeout: 5)
        let head = String(decoding: data.prefix(while: { $0 != 0x07 }), as: UTF8.self)
        XCTAssertTrue(head.hasPrefix("HTTP/1.1 206 Partial Content\r\n"))
        XCTAssertTrue(head.contains("Content-Range: bytes 0-99999/100000\r\n"))
    }

    /// Starts a loopback listener and returns its port.
    private func listen(_ accept: @escaping (NWConnection) -> Void) throws -> UInt16 {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: params)
        listeners.append(listener)
        let ready = expectation(description: "listener ready")
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.newConnectionHandler = { [weak self] conn in
            self?.connections.append(conn)
            conn.start(queue: .global())
            accept(conn)
        }
        listener.start(queue: .global())
        wait(for: [ready], timeout: 5)
        return listener.port!.rawValue
    }
}
