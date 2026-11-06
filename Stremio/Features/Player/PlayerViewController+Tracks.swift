import MobileVLCKit
import UIKit

extension PlayerViewController {
    func trackList(indexes: [Any]?, names: [Any]?) -> [(Int32, String)] {
        guard let indexes, let names, indexes.count == names.count else { return [] }
        return zip(indexes, names).compactMap { idx, nm in
            guard let i = (idx as? NSNumber)?.int32Value, let n = nm as? String else { return nil }
            return (i, n)
        }
    }

    /// Gives the audio and subtitle buttons their menus. The items are built each time a menu
    /// opens, because VLC finds tracks and the add-ons send subtitles after playback starts.
    func setupTrackMenus() {
        for (button, title, items) in [
            (audioButton, "Audio", audioMenuItems),
            (subsButton, "Subtitles", subtitleMenuItems),
        ] as [(MenuButton, String, () -> [UIMenuElement])] {
            button.showsMenuAsPrimaryAction = true
            button.preferredMenuElementOrder = .fixed
            button.menu = UIMenu(
                title: title,
                children: [UIDeferredMenuElement.uncached { completion in completion(items()) }])
            button.onMenuOpen = { [weak self] in self?.controlsTimer?.invalidate() }
            button.onMenuClose = { [weak self] in self?.scheduleControlsHide() }
        }
    }

    private func audioMenuItems() -> [UIMenuElement] {
        guard let player else { return [] }
        let tracks = trackList(indexes: player.audioTrackIndexes, names: player.audioTrackNames)
        if tracks.isEmpty { return [Self.placeholder("No audio tracks")] }
        return tracks.map { index, name in
            UIAction(title: name, state: index == player.currentAudioTrackIndex ? .on : .off) { _ in
                player.currentAudioTrackIndex = index
            }
        }
    }

    private func subtitleMenuItems() -> [UIMenuElement] {
        guard let player else { return [] }
        // VLC lists "Disable" first, with index -1.
        let embedded = trackList(indexes: player.videoSubTitlesIndexes, names: player.videoSubTitlesNames)
        var items: [UIMenuElement] = embedded.map { index, name in
            let active = selectedExternalSubtitle == nil && index == player.currentVideoSubTitleIndex
            return UIAction(title: index == -1 ? "Off" : name, state: active ? .on : .off) { _ in
                self.selectedExternalSubtitle = nil
                player.currentVideoSubTitleIndex = index
            }
        }
        // Subtitles from Stremio's subtitle add-ons, one per language.
        var seenLang = Set<String>()
        for sub in playback.externalSubtitles where seenLang.insert(sub.lang.lowercased()).inserted {
            let name = Self.languageName(sub.lang)
            let active = selectedExternalSubtitle == sub.url
            items.append(
                UIAction(title: name, subtitle: "Online", state: active ? .on : .off) { _ in
                    // VLC fetches the file itself; enforce=true makes it the active track.
                    player.addPlaybackSlave(sub.url, type: .subtitle, enforce: true)
                    self.selectedExternalSubtitle = sub.url
                    self.flashToast(name)
                })
        }
        if embedded.count <= 1 && playback.externalSubtitles.isEmpty {
            items.append(Self.placeholder("No subtitles for this stream"))
        }
        return items
    }

    private static func placeholder(_ title: String) -> UIAction {
        UIAction(title: title, attributes: .disabled) { _ in }
    }

    private static func languageName(_ code: String) -> String {
        let c = code.trimmingCharacters(in: .whitespaces)
        if c.isEmpty { return "Unknown" }
        if c.count <= 3, let name = Locale.current.localizedString(forLanguageCode: c.lowercased()) {
            return name.capitalized
        }
        return c.capitalized
    }
}
