import UIKit

/// Overlay that ignores touches on its own empty areas so the underlying
/// tap-to-toggle gesture still fires; real controls (buttons/slider) still work.
final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
