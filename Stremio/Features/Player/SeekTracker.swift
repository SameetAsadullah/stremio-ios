import Foundation

/// The position the viewer asked for, until VLC gets there. While VLC waits for the data of a
/// seek, it keeps reporting the old time, so relative jumps and the progress bar must use the
/// target instead. Times are in milliseconds.
struct SeekTracker {
    enum Update: Equatable {
        case none
        case reached
        /// VLC plays but not near the target, so it dropped the seek. Send it again.
        case reissue(Int)
        case gaveUp
    }

    static let tolerance = 3000
    static let reissueAfter: TimeInterval = 4
    static let maxReissues = 2

    private(set) var target: Int?
    private var issuedAt = Date.distantPast
    private var reissues = 0

    /// Where a relative jump starts from.
    func base(current: Int) -> Int { target ?? current }

    /// The target for a jump of `delta`, kept inside the video.
    func jump(from current: Int, by delta: Int, duration: Int) -> Int {
        let wanted = base(current: current) + delta
        let last = duration > 0 ? max(0, duration - 1000) : Int.max
        return min(max(0, wanted), last)
    }

    mutating func seek(to time: Int, now: Date = Date()) {
        target = time
        issuedAt = now
        reissues = 0
    }

    /// Called when VLC reports a new time.
    mutating func update(time: Int, now: Date = Date()) -> Update {
        guard let target else { return .none }
        if abs(time - target) < Self.tolerance {
            self.target = nil
            return .reached
        }
        guard now.timeIntervalSince(issuedAt) >= Self.reissueAfter else { return .none }
        if reissues < Self.maxReissues {
            reissues += 1
            issuedAt = now
            return .reissue(target)
        }
        self.target = nil
        return .gaveUp
    }

    /// "4:05" or "1:02:05".
    static func clock(_ ms: Int) -> String {
        let total = max(0, ms) / 1000
        let (h, m, s) = (total / 3600, total / 60 % 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
