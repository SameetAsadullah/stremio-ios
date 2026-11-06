import MediaPlayer
import MobileVLCKit
import UIKit

/// Lock screen, Control Center and headphone controls.
extension PlayerViewController {
    /// The player that owns the shared Now Playing state. When the next episode opens, the new
    /// player can set up before the old one is gone.
    private static weak var nowPlayingOwner: PlayerViewController?

    func setupRemoteCommands() {
        Self.nowPlayingOwner = self
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.preferredIntervals = [10]
        let handlers: [(MPRemoteCommand, (MPRemoteCommandEvent) -> Bool)] = [
            (center.playCommand, { [weak self] _ in self?.setPlaying(true) ?? false }),
            (center.pauseCommand, { [weak self] _ in self?.setPlaying(false) ?? false }),
            (
                center.togglePlayPauseCommand,
                { [weak self] _ in self?.setPlaying(!(self?.player?.isPlaying ?? true)) ?? false }
            ),
            (center.skipForwardCommand, { [weak self] _ in self?.skip(by: 10_000) != nil }),
            (center.skipBackwardCommand, { [weak self] _ in self?.skip(by: -10_000) != nil }),
            (
                center.changePlaybackPositionCommand,
                { [weak self] event in
                    guard let self, self.player != nil, let event = event as? MPChangePlaybackPositionCommandEvent
                    else { return false }
                    self.seek(to: Int(event.positionTime * 1000))
                    return true
                }
            ),
        ]
        remoteTargets = handlers.map { command, handler in
            command.isEnabled = true
            let target = command.addTarget { handler($0) ? .success : .commandFailed }
            return (command, target)
        }
    }

    func teardownRemoteCommands() {
        for (command, target) in remoteTargets { command.removeTarget(target) }
        remoteTargets = []
        if Self.nowPlayingOwner === self || Self.nowPlayingOwner == nil {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }

    /// iOS moves the elapsed time on by itself from the rate, so this runs only on changes and with
    /// the 5-second progress report.
    func updateNowPlaying() {
        guard let player, Self.nowPlayingOwner === self else { return }
        let episode = streamInfo?.episode
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode ?? streamInfo?.name ?? "Stremio",
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? Double(player.rate) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(max(0, player.time.intValue)) / 1000,
        ]
        if episode != nil, let name = streamInfo?.name { info[MPMediaItemPropertyArtist] = name }
        if let length = player.media?.length.intValue, length > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = Double(length) / 1000
        }
        if let nowPlayingArtwork { info[MPMediaItemPropertyArtwork] = nowPlayingArtwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func loadArtwork() {
        guard nowPlayingArtwork == nil, let url = streamInfo?.poster else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.nowPlayingArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.updateNowPlaying()
            }
        }.resume()
    }
}
