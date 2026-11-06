import UIKit

extension PlayerViewController {
    func setupNextButton() {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .white
        config.baseForegroundColor = .black
        config.cornerStyle = .medium
        config.image = UIImage(systemName: "forward.end.fill")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 16)
        var title = AttributedString("Next Episode")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        config.attributedTitle = title
        nextButton.configuration = config
        nextButton.isHidden = true
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(didTapNext), for: .touchUpInside)
        view.addSubview(nextButton)
        NSLayoutConstraint.activate([
            nextButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            nextButton.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: -20),
        ])
    }

    func loadStreamInfo() {
        playback.streamInfo { [weak self] info in
            DispatchQueue.main.async {
                guard let self, let info else { return }
                self.streamInfo = info
                self.updateTitle()
                self.updateNowPlaying()
                self.loadArtwork()
            }
        }
    }

    /// Shows the button once the credits are likely to have started.
    func updateNextButton(time: Int, duration: Int) {
        guard duration > 0 else { return }
        let remaining = duration - time
        // Stremio can find the next episode after playback starts, so ask again near the end.
        if streamInfo?.next == nil, remaining < 180_000, !refetchedStreamInfo {
            refetchedStreamInfo = true
            loadStreamInfo()
        }
        guard let info = streamInfo, info.next != nil else { return }
        let show = remaining > 0 && remaining <= info.nextEpisodeLead(duration: duration)
        guard nextButton.isHidden == show else { return }
        nextButton.alpha = show ? 0 : 1
        nextButton.isHidden = false
        UIView.animate(withDuration: 0.25) {
            self.nextButton.alpha = show ? 1 : 0
        } completion: { _ in
            self.nextButton.isHidden = !show
        }
    }

    /// At the end of the video, Stremio's player plays the next episode when binge watching is on
    /// and otherwise goes back. A stream that breaks early also ends VLC, so only a stop near the
    /// end counts.
    func handleEnded() {
        let duration = Int(player?.media?.length.intValue ?? 0)
        let time = lastObserved?.time ?? lastReportedTime
        guard duration > 0, duration - time < 60_000 else {
            Log.player.info("VLC ended at \(time) of \(duration), not at the end")
            return
        }
        playback.report(.ended)
        if let info = streamInfo, info.next != nil, info.bingeWatching {
            playNext()
        } else {
            close()
        }
    }

    @objc private func didTapNext() {
        playNext()
    }

    func playNext() {
        guard !closed else { return }
        closed = true
        reportTime(seek: true)
        stopPlayerAsync()
        playback.playNext(orElse: onClose)
    }
}
