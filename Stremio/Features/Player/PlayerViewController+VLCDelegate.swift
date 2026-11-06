import MobileVLCKit
import UIKit

extension PlayerViewController: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player else { return }
        NSLog("[STREMIOAPP] VLC state=%ld isPlaying=%d", player.state.rawValue, player.isPlaying)
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
            NSLog("[STREMIOAPP][tv] resumed at %.3f", p)
        }
        if !hasRenderedFrame {
            hasRenderedFrame = true
            spinner.stopAnimating()
            NSLog("[STREMIOAPP] first frame at %@", player.time.stringValue)
            stopStatsPolling()
            scheduleControlsHide()
            #if VLC_SELFTEST
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, let player = self.player else { return }
                let subs = self.trackList(indexes: player.videoSubTitlesIndexes, names: player.videoSubTitlesNames)
                if let t = subs.first(where: { $0.0 != -1 }) {
                    player.currentVideoSubTitleIndex = t.0
                    player.position = 0.08
                    NSLog("[STREMIOAPP] selftest picked subtitle %d '%@' of %d", t.0, t.1, subs.count)
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
