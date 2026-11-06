import MobileVLCKit
import UIKit

/// Forwards libvlc's own log (HTTP status, demux/decoder errors) into the
/// unified log so failures are diagnosable from `log show`.
final class VLCLogBridge: NSObject, VLCLogging {
    var level: VLCLogLevel = .debug
    func handleMessage(_ message: String, logLevel: VLCLogLevel, context: VLCLogContext?) {
        let m = message.lowercased()
        let keep = (logLevel == .error || logLevel == .warning || m.contains("http")
            || m.contains("using demux") || m.contains("decoder") || m.contains("codec")
            || m.contains("videotoolbox")) && !m.contains("too late") && !m.contains("displayed late")
        guard keep && message.count < 400 else { return }
        if logLevel == .error {
            Log.player.error("vlc: \(message, privacy: .public)")
        } else {
            Log.player.debug("vlc: \(message, privacy: .public)")
        }
    }
}
