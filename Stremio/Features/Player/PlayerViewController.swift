import AVFoundation
import Combine
import MediaPlayer
import MobileVLCKit
import UIKit

final class PlayerViewController: UIViewController {
    let stream: PlaybackController.Stream
    let playback: PlaybackController
    let onClose: () -> Void
    var player: VLCMediaPlayer!
    var selectedExternalSubtitle: URL?

    let videoView = UIView()
    private let tapCatcher = UIView()  // above VLC's render view, owns the gestures
    let spinner = UIActivityIndicatorView(style: .large)
    let statusLabel = UILabel()
    let controls = PassthroughView()
    private let scrim = UIView()

    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    let tracksButton = MenuButton(type: .system)
    private let castButton = UIButton(type: .system)
    private let tvPlaceholder = UIStackView()
    private var tvCancellable: AnyCancellable?
    var pendingPosition: Float?
    private let playPauseButton = UIButton(type: .system)
    private let skipBackButton = UIButton(type: .system)
    private let skipForwardButton = UIButton(type: .system)
    let slider = UISlider()
    let elapsedLabel = UILabel()
    let remainingLabel = UILabel()
    let toastLabel = UILabel()
    var errorView: UIView?

    var controlsTimer: Timer?
    var toastTimer: Timer?
    var statsTimer: Timer?
    var isScrubbing = false
    var hasRenderedFrame = false
    var lastReportedTime = 0
    /// Last VLC time and the wall clock at that moment, to tell a seek from normal playback.
    var lastObserved: (time: Int, at: Date)?
    var closed = false
    let nextButton = UIButton(type: .system)
    var streamInfo: StreamInfo?
    var refetchedStreamInfo = false
    var seekTracker = SeekTracker()
    var stallTimer: Timer?
    var lastAdvance = Date()
    var stallStatusShown = false
    /// False after the viewer pauses, so a pause is not shown as buffering.
    var wantsPlaying = true
    var remoteTargets: [(MPRemoteCommand, Any)] = []
    var nowPlayingArtwork: MPMediaItemArtwork?

    var zoom: CGFloat = 1  // 1 = fit; >1 zoomed/filled
    var filled = false
    private static let vlcLogger = VLCLogBridge()

    init(stream: PlaybackController.Stream, playback: PlaybackController, onClose: @escaping () -> Void) {
        self.stream = stream
        self.playback = playback
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        Log.player.debug("player VC deinit")
        stopPlayerAsync()
    }

    private static func symbol(_ name: String, size: CGFloat, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight))
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.clipsToBounds = true
        setupVideoView()
        setupGestures()
        setupSpinner()
        setupControls()
        setupNextButton()
        startPlayback()
        NotificationCenter.default.addObserver(
            self, selector: #selector(saveProgress), name: UIApplication.willResignActiveNotification, object: nil)
    }

    // MARK: - Layout

    private func setupVideoView() {
        videoView.backgroundColor = .black
        videoView.frame = view.bounds
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(videoView)

        let icon = UIImageView(
            image: UIImage(systemName: "tv", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44)))
        icon.tintColor = UIColor.white.withAlphaComponent(0.9)
        let label = UILabel()
        label.text = "Playing on your TV"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        let sub = UILabel()
        sub.text = "Use the controls here."
        sub.textColor = UIColor.white.withAlphaComponent(0.6)
        sub.font = .systemFont(ofSize: 14)
        tvPlaceholder.axis = .vertical
        tvPlaceholder.alignment = .center
        tvPlaceholder.spacing = 8
        for item in [icon, label, sub] { tvPlaceholder.addArrangedSubview(item) }
        tvPlaceholder.isHidden = true
        tvPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tvPlaceholder)
        NSLayoutConstraint.activate([
            tvPlaceholder.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tvPlaceholder.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -90),
        ])

        tapCatcher.frame = view.bounds
        tapCatcher.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tapCatcher.backgroundColor = .clear
        view.addSubview(tapCatcher)
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        tap.require(toFail: doubleTap)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(didPinch))
        for g in [tap, doubleTap] as [UIGestureRecognizer] {
            g.delegate = self
            tapCatcher.addGestureRecognizer(g)
        }
        pinch.delegate = self
        tapCatcher.addGestureRecognizer(pinch)
    }

    private func setupSpinner() {
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)

        statusLabel.text = "Connecting to stream\u{2026}"
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        toastLabel.textColor = .white
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        toastLabel.textAlignment = .center
        toastLabel.layer.cornerRadius = 8
        toastLabel.layer.masksToBounds = true
        toastLabel.alpha = 0
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toastLabel)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 72),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            toastLabel.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    private func setupControls() {
        controls.frame = view.bounds
        controls.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controls)

        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        scrim.frame = controls.bounds
        scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrim.isUserInteractionEnabled = false
        controls.addSubview(scrim)

        configureIcon(closeButton, "xmark", action: #selector(didTapClose), size: 17, weight: .semibold)
        configureIcon(tracksButton, "captions.bubble", size: 19)
        setupTrackMenu()
        configureIcon(castButton, "airplayvideo", action: #selector(didTapCast), size: 19)
        for b in [closeButton, tracksButton, castButton] {
            NSLayoutConstraint.activate([
                b.widthAnchor.constraint(equalToConstant: 44), b.heightAnchor.constraint(equalToConstant: 44),
            ])
        }
        configureIcon(playPauseButton, "pause.fill", action: #selector(didTapPlayPause), size: 48)
        configureIcon(skipBackButton, "gobackward.10", action: #selector(didTapSkipBack), size: 32)
        configureIcon(skipForwardButton, "goforward.10", action: #selector(didTapSkipForward), size: 32)
        for b in [closeButton, playPauseButton, skipBackButton, skipForwardButton] { controls.addSubview(b) }

        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        controls.addSubview(titleLabel)

        let topRight = UIStackView(arrangedSubviews: [tracksButton, castButton])
        topRight.axis = .horizontal
        topRight.spacing = 4
        topRight.translatesAutoresizingMaskIntoConstraints = false
        controls.addSubview(topRight)

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.minimumTrackTintColor = .white
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(scrubStart), for: .touchDown)
        slider.addTarget(self, action: #selector(scrubChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(scrubEnd), for: [.touchUpInside, .touchUpOutside])
        controls.addSubview(slider)

        for label in [elapsedLabel, remainingLabel] {
            label.textColor = .white
            label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            label.translatesAutoresizingMaskIntoConstraints = false
            controls.addSubview(label)
        }
        remainingLabel.textAlignment = .right

        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            // The 44 pt buttons have their own padding, so they sit closer to the edges.
            closeButton.topAnchor.constraint(equalTo: g.topAnchor, constant: 4),
            closeButton.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 4),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: topRight.leadingAnchor, constant: -12),
            topRight.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            topRight.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -4),

            playPauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            skipBackButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            skipBackButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -44),
            skipForwardButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            skipForwardButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 44),

            elapsedLabel.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            elapsedLabel.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -12),
            remainingLabel.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            remainingLabel.centerYAnchor.constraint(equalTo: elapsedLabel.centerYAnchor),
            slider.leadingAnchor.constraint(equalTo: elapsedLabel.trailingAnchor, constant: 8),
            slider.trailingAnchor.constraint(equalTo: remainingLabel.leadingAnchor, constant: -8),
            slider.centerYAnchor.constraint(equalTo: elapsedLabel.centerYAnchor),
        ])
    }

    private func configureIcon(
        _ b: UIButton, _ name: String, action: Selector? = nil, size: CGFloat, weight: UIImage.SymbolWeight = .regular
    ) {
        b.setImage(Self.symbol(name, size: size, weight: weight), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        if let action { b.addTarget(self, action: action, for: .touchUpInside) }
    }

    // MARK: - Playback

    func startPlayback() {
        VLCLibrary.shared().loggers = [Self.vlcLogger]
        player = VLCMediaPlayer()

        // The loopback relay holds VLC's connection while a cold torrent starts.
        let playURL = StreamProxy.shared.register(origin: stream.url)
        let media = VLCMedia(url: playURL)
        media.addOption(":network-caching=4000")
        media.addOption(":avcodec-skiploopfilter=3")
        media.addOption(":avcodec-threads=0")
        if stream.startTime > 0 { media.addOption(":start-time=\(Double(stream.startTime) / 1000)") }
        Log.player.info("VLC opening \(playURL.absoluteString) -> \(self.stream.url.absoluteString)")
        player.media = media
        player.delegate = self
        applySubtitleSize(SubtitleSize.saved())
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        applyRenderTarget(ExternalDisplay.shared.view)
        tvCancellable = ExternalDisplay.shared.$view
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.applyRenderTarget(v) }
        player.play()
        loadStreamInfo()
        setupRemoteCommands()
        startStatsPolling()
        scheduleControlsHide()
    }

    /// Never call VLCMediaPlayer.stop() on the main thread — on a stuck network
    /// input it blocks, which is what froze "close" mid-buffer. Detach it.
    func stopPlayerAsync() {
        teardownRemoteCommands()
        stopStallWatch()
        tvCancellable = nil
        statsTimer?.invalidate()
        statsTimer = nil
        controlsTimer?.invalidate()
        controlsTimer = nil
        guard let p = player else { return }
        player = nil
        DispatchQueue.global(qos: .userInitiated).async { p.stop() }
    }

    /// Route VLC's output to the TV when one is attached, back to the phone when not.
    /// libvlc won't re-parent a live video output, so if we're already playing we
    /// restart on the new surface and seek back to where we were (~1s blip).
    private func applyRenderTarget(_ tv: UIView?) {
        guard let player else { return }
        let target: UIView = tv ?? videoView
        tvPlaceholder.isHidden = (tv == nil)
        if tv != nil {
            videoView.transform = .identity
            zoom = 1
            filled = false
        }
        let live = hasRenderedFrame && (player.isPlaying || player.state == .paused || player.state == .buffering)
        if live, let media = player.media {
            let pos = player.position
            player.stop()
            player.drawable = target
            player.media = media
            pendingPosition = pos > 0.001 ? pos : nil
            player.play()
            Log.tv.info("restarted on \(tv == nil ? "phone" : "external display", privacy: .public) at \(pos)")
        } else {
            player.drawable = target
            Log.tv.info("rendering on \(tv == nil ? "phone" : "external display", privacy: .public)")
        }
    }

    @objc private func didTapCast() {
        let onTV = ExternalDisplay.shared.isConnected
        let title = onTV ? "Playing on your TV" : "Play on a TV"
        let msg =
            onTV
            ? "The video is on the connected display. Disconnect AirPlay / the HDMI adapter to bring it back to the phone."
            : "Plays any file on any TV \u{2014} the phone decodes it and sends the picture:\n\n1. Open Control Center\n2. Tap Screen Mirroring\n3. Pick your Apple TV or AirPlay TV\n\nThe video fills the TV (not a mirrored phone screen) and you keep the controls here. A USB-C/Lightning-to-HDMI adapter works the same way."
        let sheet = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        sheet.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.scheduleControlsHide() })
        present(sheet, animated: true)
        controlsTimer?.invalidate()
    }

    /// Sends the position to Stremio. Before the first frame, or while a restart seeks back, VLC
    /// reports 0, which would overwrite the saved position.
    func reportTime(seek: Bool = false) {
        guard let player, hasRenderedFrame, pendingPosition == nil else { return }
        let time = seekTracker.target ?? Int(player.time.intValue)
        let duration = Int(player.media?.length.intValue ?? 0)
        guard time > 0 else { return }
        lastReportedTime = time
        updateNowPlaying()
        if seek {
            playback.report(.seek(time, duration: duration))
        } else {
            playback.report(.time(time, duration: duration))
        }
    }

    /// iOS can kill the app from the app switcher without notice, and Stremio writes the position
    /// only on unload, on a pause change, or every 3 minutes. A pause change saves it at once.
    @objc private func saveProgress() {
        guard let player, hasRenderedFrame else { return }
        reportTime(seek: true)
        playback.report(.paused(!player.isPlaying))
    }

    /// Reports the position while VLC plays: as a seek when the time jumped, else every 5 s.
    func trackProgress() {
        guard let player, hasRenderedFrame, pendingPosition == nil else { return }
        let time = Int(player.time.intValue)
        let now = Date()
        defer { lastObserved = (time, now) }
        updateNextButton(time: time, duration: Int(player.media?.length.intValue ?? 0))
        if let last = lastObserved {
            let played = time - last.time
            let elapsed = Int(now.timeIntervalSince(last.at) * 1000)
            if abs(played - elapsed) > 3000 {
                reportTime(seek: true)
                return
            }
        }
        if abs(time - lastReportedTime) >= 5000 { reportTime() }
    }

    // MARK: - Actions

    @objc private func didTapClose() {
        close()
    }

    /// Show name with the episode under it. The page title is always "Stremio - Freedom to
    /// Stream" on the player page, so the label stays empty until Stremio's info arrives.
    func updateTitle() {
        guard let name = streamInfo?.name else { return }
        let text = NSMutableAttributedString(
            string: name,
            attributes: [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: UIColor.white])
        if let episode = streamInfo?.episode {
            text.append(
                NSAttributedString(
                    string: "\n" + episode,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.white.withAlphaComponent(0.7),
                    ]))
        }
        titleLabel.attributedText = text
    }

    func close() {
        guard !closed else { return }
        closed = true
        reportTime(seek: true)
        stopPlayerAsync()  // detached, non-blocking
        onClose()  // dismiss immediately
    }

    @objc private func didTapPlayPause() {
        setPlaying(!(player?.isPlaying ?? true))
        scheduleControlsHide()
    }

    /// Returns false when there is no player.
    @discardableResult
    func setPlaying(_ playing: Bool) -> Bool {
        guard let player else { return false }
        wantsPlaying = playing
        // A long pause is not a stall.
        if playing { lastAdvance = Date() }
        if playing { player.play() } else { player.pause() }
        updatePlayPauseIcon(playing: playing)
        return true
    }

    func updatePlayPauseIcon(playing: Bool) {
        playPauseButton.setImage(Self.symbol(playing ? "pause.fill" : "play.fill", size: 48), for: .normal)
    }

    @objc private func didTapSkipBack() {
        skip(by: -10_000)
        scheduleControlsHide()
    }
    @objc private func didTapSkipForward() {
        skip(by: 10_000)
        scheduleControlsHide()
    }
    @objc private func scrubStart() { isScrubbing = true }
    @objc private func scrubEnd() {
        if durationMs > 0 {
            seek(to: Int(Double(slider.value) * Double(durationMs)))
        } else {
            player?.position = slider.value
        }
        isScrubbing = false
        scheduleControlsHide()
    }
}
