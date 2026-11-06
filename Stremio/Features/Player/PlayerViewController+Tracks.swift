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

    @objc func showAudioMenu() {
        guard let player else { return }
        let tracks = trackList(indexes: player.audioTrackIndexes, names: player.audioTrackNames)
        presentTrackSheet(title: "Audio", tracks: tracks, current: player.currentAudioTrackIndex, from: audioButton) {
            player.currentAudioTrackIndex = $0
        }
    }

    @objc func showSubtitleMenu() {
        guard let player else { return }
        let embedded = trackList(indexes: player.videoSubTitlesIndexes, names: player.videoSubTitlesNames)
        let online = playback.externalSubtitles
        let sheet = UIAlertController(title: "Subtitles",
                                      message: (embedded.count <= 1 && online.isEmpty) ? "No subtitles for this stream" : nil,
                                      preferredStyle: .actionSheet)
        // Embedded tracks (VLC lists "Disable" first with index -1).
        for (index, name) in embedded {
            let active = selectedExternalSubtitle == nil && index == player.currentVideoSubTitleIndex
            let label = index == -1 ? "Off" : name
            sheet.addAction(UIAlertAction(title: (active ? "\u{2713} " : "") + label, style: .default) { _ in
                self.selectedExternalSubtitle = nil
                player.currentVideoSubTitleIndex = index
                self.scheduleControlsHide()
            })
        }
        // Online tracks from Stremio's subtitle addons, one per language.
        var seenLang = Set<String>()
        for sub in online where seenLang.insert(sub.lang.lowercased()).inserted {
            let active = selectedExternalSubtitle == sub.url
            sheet.addAction(UIAlertAction(title: (active ? "\u{2713} " : "") + Self.languageName(sub.lang) + " (online)", style: .default) { _ in
                // VLC fetches the file itself; enforce=true makes it the active track.
                player.addPlaybackSlave(sub.url, type: .subtitle, enforce: true)
                self.selectedExternalSubtitle = sub.url
                self.flashToast(Self.languageName(sub.lang))
                self.scheduleControlsHide()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.sourceView = subsButton; pop.sourceRect = subsButton.bounds }
        present(sheet, animated: true)
        controlsTimer?.invalidate()
    }

    private static func languageName(_ code: String) -> String {
        let c = code.trimmingCharacters(in: .whitespaces)
        if c.isEmpty { return "Unknown" }
        if c.count <= 3, let name = Locale.current.localizedString(forLanguageCode: c.lowercased()) { return name.capitalized }
        return c.capitalized
    }

    private func presentTrackSheet(title: String, tracks: [(Int32, String)], current: Int32,
                                   from source: UIView, apply: @escaping (Int32) -> Void) {
        let sheet = UIAlertController(title: title, message: tracks.isEmpty ? "No tracks available" : nil, preferredStyle: .actionSheet)
        for (index, name) in tracks {
            let mark = index == current ? "\u{2713} " : ""
            sheet.addAction(UIAlertAction(title: mark + name, style: .default) { _ in apply(index); self.scheduleControlsHide() })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.sourceView = source; pop.sourceRect = source.bounds }
        present(sheet, animated: true)
        controlsTimer?.invalidate()   // keep controls up while the menu is open
    }
}
