import UIKit

/// Turns Stremio to landscape while a player is on screen, and back to the orientation it had
/// before the first player opened. The phone's own orientation is no guide: with rotation lock
/// on, iOS reports the forced landscape.
final class PlayerOrientation {
    private var saved: (scene: UIWindowScene, orientation: UIInterfaceOrientation)?
    private var pendingRestore: DispatchWorkItem?

    /// The next episode opens a new player in landscape, so only the first player saves.
    func playerAppeared(in scene: UIWindowScene) {
        cancelPendingRestore()
        if saved == nil { saved = (scene, scene.interfaceOrientation) }
        Self.request(.landscape, in: scene)
    }

    func restore() {
        cancelPendingRestore()
        guard let saved else { return }
        self.saved = nil
        if saved.orientation.isPortrait, !saved.scene.interfaceOrientation.isPortrait {
            Self.request(.portrait, in: saved.scene)
        }
    }

    /// For a player that closed for the next episode. Stremio can show the stream list or an
    /// error instead of a new player.
    func restoreUnlessPlayerOpens() {
        guard saved != nil else { return }
        let work = DispatchWorkItem { [weak self] in self?.restore() }
        cancelPendingRestore()
        pendingRestore = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func cancelPendingRestore() {
        pendingRestore?.cancel()
        pendingRestore = nil
    }

    private static func request(_ orientations: UIInterfaceOrientationMask, in scene: UIWindowScene) {
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { error in
            Log.player.error("orientation request failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
