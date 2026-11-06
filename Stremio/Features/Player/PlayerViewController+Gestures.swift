import UIKit

extension PlayerViewController: UIGestureRecognizerDelegate {
    @objc func didDoubleTap() {
        filled.toggle()
        applyZoom(fillIfPossible: filled, animated: true)
        flashToast(filled ? "Fill" : "Fit")
    }

    @objc func didPinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .changed:
            let z = min(max(zoom * g.scale, 1), 4)
            videoView.transform = CGAffineTransform(scaleX: z, y: z)
        case .ended, .cancelled:
            zoom = min(max(zoom * g.scale, 1), 4)
            filled = zoom > 1.01
            flashToast(zoom <= 1.01 ? "Fit" : String(format: "%.0f%%", Double(zoom) * 100))
        default: break
        }
    }

    /// Fit = 1x (VLC letterboxes). Fill = scale the whole render view until the
    /// video edges reach the screen, cropping the letterbox bars.
    private func applyZoom(fillIfPossible: Bool, animated: Bool) {
        var target: CGFloat = 1
        if fillIfPossible {
            let vs = player?.videoSize ?? .zero
            let b = view.bounds.size
            if vs.width > 0, vs.height > 0, b.width > 0, b.height > 0 {
                let fit = min(b.width / vs.width, b.height / vs.height)
                let fill = max(b.width / vs.width, b.height / vs.height)
                if fit > 0 { target = fill / fit }
            } else {
                target = max(b.width, b.height) / min(b.width, b.height)  // best-effort before videoSize known
            }
        }
        zoom = target
        let apply = { self.videoView.transform = CGAffineTransform(scaleX: target, y: target) }
        animated ? UIView.animate(withDuration: 0.25, animations: apply) : apply()
    }

    func flashToast(_ text: String) {
        toastLabel.text = "  \(text)  "
        toastTimer?.invalidate()
        UIView.animate(withDuration: 0.15) { self.toastLabel.alpha = 1 }
        toastTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            UIView.animate(withDuration: 0.3) { self?.toastLabel.alpha = 0 }
        }
    }

    // MARK: - Controls visibility

    @objc func toggleControls() { setControls(hidden: controls.alpha > 0) }

    func setControls(hidden: Bool) {
        UIView.animate(withDuration: 0.25) { self.controls.alpha = hidden ? 0 : 1 }
        if !hidden { scheduleControlsHide() }
    }

    func scheduleControlsHide() {
        #if VLC_SELFTEST
            return
        #endif
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.player?.isPlaying == true { self.setControls(hidden: true) } else { self.scheduleControlsHide() }
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl)
    }
    func gestureRecognizer(
        _ g: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}
