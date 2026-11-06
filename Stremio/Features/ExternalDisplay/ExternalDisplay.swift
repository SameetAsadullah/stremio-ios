import Combine
import UIKit

/// TV output. When the phone is AirPlay-mirroring (Apple TV, AirPlay-2 TVs) or on
/// an HDMI adapter, iOS hands the app a second, non-interactive display scene.
/// We render the *decoded* video straight onto it — full quality, any codec —
/// while the phone keeps the controls. This is how VLC for iOS does TV output,
/// and it sidesteps the fact that TVs can't decode torrent MKV/HEVC/AC3 themselves.
final class ExternalDisplay: ObservableObject {
    static let shared = ExternalDisplay()
    @Published private(set) var view: UIView?
    var isConnected: Bool { view != nil }

    fileprivate func attach(_ v: UIView) { DispatchQueue.main.async { self.view = v } }
    fileprivate func detach() { DispatchQueue.main.async { self.view = nil } }
}

final class ExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        let vc = ExternalDisplayViewController()
        w.rootViewController = vc
        w.isHidden = false
        window = w
        Log.tv.info(
            "external display connected screen=\(NSCoder.string(for: ws.screen.bounds.size), privacy: .public) window=\(NSCoder.string(for: w.bounds.size), privacy: .public)"
        )
        ExternalDisplay.shared.attach(vc.videoSurface)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        Log.tv.info("external display disconnected")
        ExternalDisplay.shared.detach()
        window = nil
    }
}

/// Root of the TV window: a branded idle screen, with a full-bleed surface VLC draws into.
final class ExternalDisplayViewController: UIViewController {
    let videoSurface = UIView()
    private let idle = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.055, green: 0.043, blue: 0.12, alpha: 1)
        videoSurface.backgroundColor = .clear
        videoSurface.frame = view.bounds
        videoSurface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(videoSurface)
        idle.text = "Stremio"
        idle.textColor = UIColor.white.withAlphaComponent(0.35)
        idle.font = .systemFont(ofSize: 48, weight: .semibold)
        idle.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(idle, belowSubview: videoSurface)
        NSLayoutConstraint.activate([
            idle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            idle.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let viewSize = NSCoder.string(for: view.bounds.size)
        let surfaceSize = NSCoder.string(for: videoSurface.bounds.size)
        Log.tv.debug("external view laid out \(viewSize, privacy: .public) surface=\(surfaceSize, privacy: .public)")
    }
}
