import UIKit

extension PlayerViewController {
    static func statsURL(for streamURL: URL) -> URL? {
        let parts = streamURL.pathComponents.filter { $0 != "/" }
        guard let hash = parts.first, hash.count == 40,
            var components = URLComponents(url: streamURL, resolvingAgainstBaseURL: false)
        else { return nil }
        components.path = "/\(hash)/stats.json"
        components.query = nil
        return components.url
    }

    func startStatsPolling() {
        guard let url = Self.statsURL(for: stream.url) else {
            statusLabel.isHidden = true
            return
        }
        statusLabel.isHidden = false
        let started = Date()
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, !self.hasRenderedFrame else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }
                let peers = json["peers"] as? Int ?? 0
                let speed = (json["downloadSpeed"] as? Double ?? 0) / 1_000_000
                let ready = (json["downloaded"] as? Double ?? 0) / 1_000_000
                let waited = Int(Date().timeIntervalSince(started))
                let text: String
                if peers == 0 && waited > 30 {
                    text = "No sources found after \(waited)s. This stream may be dead \u{2014} try another one."
                } else if peers == 0 {
                    text = "Finding sources\u{2026}"
                } else {
                    text = String(
                        format: "Buffering from %d sources \u{00B7} %.1f MB/s \u{00B7} %.0f MB ready", peers, speed,
                        ready)
                }
                DispatchQueue.main.async { self.statusLabel.text = text }
            }.resume()
        }
    }

    func stopStatsPolling() {
        statsTimer?.invalidate()
        statsTimer = nil
        statusLabel.isHidden = true
    }

    // MARK: - Error / retry

    func showError(_ message: String) {
        stopStatsPolling()
        spinner.stopAnimating()
        guard errorView == nil else { return }
        let title = UILabel()
        title.text = "Stream didn\u{2019}t start"
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        title.textAlignment = .center
        let body = UILabel()
        body.text = message
        body.numberOfLines = 0
        body.textAlignment = .center
        body.textColor = UIColor.white.withAlphaComponent(0.8)
        body.font = .systemFont(ofSize: 15)
        var retryConfig = UIButton.Configuration.filled()
        retryConfig.title = "Try again"
        retryConfig.baseBackgroundColor = .white
        retryConfig.baseForegroundColor = .black
        retryConfig.background.cornerRadius = 10
        retryConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 22, bottom: 10, trailing: 22)
        retryConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = .systemFont(ofSize: 16, weight: .semibold)
            return attrs
        }
        let retry = UIButton(configuration: retryConfig)
        retry.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, body, retry])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
        errorView = stack
        setControls(hidden: false)
    }

    @objc private func didTapRetry() {
        errorView?.removeFromSuperview()
        errorView = nil
        hasRenderedFrame = false
        spinner.startAnimating()
        stopPlayerAsync()
        startPlayback()
    }
}
