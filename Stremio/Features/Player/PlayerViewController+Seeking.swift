import MobileVLCKit
import UIKit

extension PlayerViewController {
    var durationMs: Int { Int(player?.media?.length.intValue ?? 0) }

    /// Seeks to an exact time, so a later jump or a dropped seek cannot go back to the old spot.
    func seek(to time: Int) {
        guard let player else { return }
        seekTracker.seek(to: time)
        player.time = VLCTime(int: Int32(clamping: time))
        showTime(time, moveSlider: true)
        markStalled()
    }

    func skip(by delta: Int) {
        guard let player else { return }
        seek(to: seekTracker.jump(from: Int(player.time.intValue), by: delta, duration: durationMs))
    }

    /// Updates the bar and the times. While a seek waits for data, they show the target.
    func showTime(_ time: Int, moveSlider: Bool) {
        let duration = durationMs
        guard duration > 0 else {
            elapsedLabel.text = SeekTracker.clock(time)
            return
        }
        if moveSlider { slider.value = Float(time) / Float(duration) }
        elapsedLabel.text = SeekTracker.clock(time)
        remainingLabel.text = "-" + SeekTracker.clock(duration - time)
    }

    @objc func scrubChanged() {
        showTime(Int(Double(slider.value) * Double(durationMs)), moveSlider: false)
    }

    /// Called for every VLC time update after the first frame.
    func handleTimeUpdate() {
        guard let player else { return }
        let time = Int(player.time.intValue)
        switch seekTracker.update(time: time) {
        case .reissue(let target):
            Log.player.info("VLC dropped the seek to \(target), sending it again")
            player.time = VLCTime(int: Int32(clamping: target))
        case .gaveUp:
            Log.player.error("VLC did not reach the seek target, staying at \(time)")
        case .none, .reached:
            break
        }
        // VLC's own time is stale while a seek waits, so it is not progress.
        guard seekTracker.target == nil else { return }
        lastAdvance = Date()
        hideStallStatus()
        if !isScrubbing { showTime(time, moveSlider: true) }
    }

    // MARK: - Buffering after the start

    func startStallWatch() {
        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkStall()
        }
    }

    func stopStallWatch() {
        stallTimer?.invalidate()
        stallTimer = nil
    }

    /// A seek starts a wait for data at once, so show the status without waiting for the timer.
    private func markStalled() {
        lastAdvance = .distantPast
        checkStall()
    }

    private func checkStall() {
        guard let player, hasRenderedFrame, errorView == nil, wantsPlaying, player.state != .ended else {
            hideStallStatus()
            return
        }
        guard Date().timeIntervalSince(lastAdvance) > 1, !stallStatusShown else { return }
        stallStatusShown = true
        spinner.startAnimating()
        startStatsPolling()
    }

    private func hideStallStatus() {
        guard stallStatusShown else { return }
        stallStatusShown = false
        spinner.stopAnimating()
        stopStatsPolling()
    }
}
