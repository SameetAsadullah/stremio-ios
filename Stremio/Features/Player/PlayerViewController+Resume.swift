import UIKit

extension PlayerViewController {
    func setupResumeButton() {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.6)
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.image = UIImage(systemName: "arrow.counterclockwise")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        config.imagePadding = 8
        config.titlePadding = 2
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 16)
        resumeButton.configuration = config
        resumeButton.isHidden = true
        resumeButton.translatesAutoresizingMaskIntoConstraints = false
        resumeButton.addTarget(self, action: #selector(didTapStartOver), for: .touchUpInside)
        view.addSubview(resumeButton)
        NSLayoutConstraint.activate([
            resumeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            resumeButton.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: -20),
        ])
    }

    /// Shown for a few seconds when the video picks up from the saved position.
    func showResumeNotice() {
        guard stream.startTime > 0 else { return }
        var title = AttributedString("Start Over")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        var subtitle = AttributedString("Resumed at " + SeekTracker.clock(stream.startTime))
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.foregroundColor = UIColor.white.withAlphaComponent(0.7)
        resumeButton.configuration?.attributedTitle = title
        resumeButton.configuration?.attributedSubtitle = subtitle
        setResumeButton(hidden: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.setResumeButton(hidden: true) }
    }

    private func setResumeButton(hidden: Bool) {
        guard resumeButton.isHidden != hidden else { return }
        resumeButton.alpha = hidden ? 1 : 0
        resumeButton.isHidden = false
        UIView.animate(withDuration: 0.25) {
            self.resumeButton.alpha = hidden ? 0 : 1
        } completion: { _ in
            self.resumeButton.isHidden = hidden
        }
    }

    @objc private func didTapStartOver() {
        seek(to: 0)
        setResumeButton(hidden: true)
    }
}
