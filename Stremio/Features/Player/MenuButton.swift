import UIKit

/// A button that opens its menu on tap and reports when the menu opens and closes, so the player
/// can keep its controls on screen while a menu is open.
final class MenuButton: UIButton {
    var onMenuOpen: (() -> Void)?
    var onMenuClose: (() -> Void)?

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
        onMenuOpen?()
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        onMenuClose?()
    }
}
