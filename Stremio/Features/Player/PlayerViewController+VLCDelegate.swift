import MobileVLCKit
import UIKit

extension PlayerViewController: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player else { return }
        Log.player.debug("VLC state=\(player.state.rawValue) isPlaying=\(player.isPlaying)")
        switch player.state {
        case .opening: if !hasRenderedFrame { spinner.startAnimating() }
        case .error:
            // Remember the spot before tearing the player down, so "Try again"
            // picks up where the viewer was instead of restarting the film.
            if player.position > 0.001 { pendingPosition = player.position }
            showError(hasRenderedFrame
                      ? "Playback stopped. The stream may have run out of sources, or the connection to the server dropped. Try again picks up where you left off."
                      : "This torrent has too few sources right now, or it\u{2019}s still finding them. Give it a moment and try again, or pick a stream with more seeders.")
        case .ended, .stopped: spinner.stopAnimating()
        default: break
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard let player else { return }
        if let p = pendingPosition, player.isPlaying {
            pendingPosition = nil
            player.position = p
            Log.tv.debug("resumed at \(p)")
        }
        if !hasRenderedFrame {
            hasRenderedFrame = true
            spinner.stopAnimating()
            Log.player.info("first frame at \(player.time.stringValue, privacy: .public)")
            stopStatsPolling()
            scheduleControlsHide()
            #if VLC_SELFTEST
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, let player = self.player else { return }
                let subs = self.trackList(indexes: player.videoSubTitlesIndexes, names: player.videoSubTitlesNames)
                if let t = subs.first(where: { $0.0 != -1 }) {
                    player.currentVideoSubTitleIndex = t.0
                    player.position = 0.08
                    Log.player.debug("selftest picked subtitle \(t.0) '\(t.1)' of \(subs.count)")
                }
            }
            #endif
        }
        guard !isScrubbing else { return }
        slider.value = player.position
        elapsedLabel.text = player.time.stringValue
        if let remaining = player.remainingTime?.stringValue { remainingLabel.text = remaining }
    }
}
