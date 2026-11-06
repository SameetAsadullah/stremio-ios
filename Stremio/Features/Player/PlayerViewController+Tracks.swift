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

    /// One "Audio & Subtitles" menu, as in Netflix. The items are built each time the menu opens,
    /// because VLC finds tracks and the add-ons send subtitles after playback starts.
    func setupTrackMenu() {
        tracksButton.showsMenuAsPrimaryAction = true
        tracksButton.preferredMenuElementOrder = .fixed
        tracksButton.menu = UIMenu(
            title: "Audio & Subtitles",
            children: [
                UIDeferredMenuElement.uncached { [weak self] completion in
                    guard let self else { return completion([]) }
                    completion([
                        UIMenu(title: "Audio", options: .displayInline, children: self.audioMenuItems()),
                        UIMenu(title: "Subtitles", options: .displayInline, children: self.subtitleMenuItems()),
                        self.subtitleSizeMenu(),
                        self.speedMenu(),
                    ])
                }
            ])
        tracksButton.onMenuOpen = { [weak self] in self?.controlsTimer?.invalidate() }
        tracksButton.onMenuClose = { [weak self] in self?.scheduleControlsHide() }
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

    /// A row of four "A"s in growing sizes, with the current size selected.
    private func subtitleSizeMenu() -> UIMenu {
        let current = SubtitleSize.saved()
        let sizes = SubtitleSize.allCases.enumerated().map { index, size in
            UIAction(title: size.title, image: Self.letterImage(step: index), state: size == current ? .on : .off) {
                _ in
                size.save()
                self.applySubtitleSize(size)
            }
        }
        return UIMenu(title: "Subtitle Size", options: [.displayInline, .displayAsPalette], children: sizes)
    }

    /// The menu scales palette images to one size, so every "A" is drawn on the same canvas and
    /// only the letter grows.
    private static func letterImage(step: Int) -> UIImage {
        let canvas = CGSize(width: 26, height: 26)
        let font = UIFont.systemFont(ofSize: 11 + CGFloat(step) * 4, weight: .semibold)
        let letter = NSAttributedString(string: "A", attributes: [.font: font, .foregroundColor: UIColor.black])
        let size = letter.size()
        return UIGraphicsImageRenderer(size: canvas).image { _ in
            letter.draw(at: CGPoint(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2))
        }.withRenderingMode(.alwaysTemplate)
    }

    /// Netflix's speeds. Each video starts at normal speed.
    private func speedMenu() -> UIMenu {
        let current = player?.rate ?? 1
        let label = { (rate: Float) in String(format: "%g\u{00D7}", rate) }
        let rates: [Float] = [0.5, 0.75, 1, 1.25, 1.5]
        return UIMenu(
            title: "Speed", subtitle: label(current), image: UIImage(systemName: "gauge.with.dots.needle.50percent"),
            children: rates.map { rate in
                UIAction(title: label(rate), state: abs(rate - current) < 0.01 ? .on : .off) { _ in
                    self.player?.rate = rate
                    self.updateNowPlaying()
                }
            })
    }

    /// Turns on the audio and subtitles in Stremio's preferred languages, once per video.
    func applyPreferredTracks() {
        guard let player, let info = streamInfo, !appliedPreferredTracks else { return }
        appliedPreferredTracks = true
        let languages = trackLanguages()
        let tracks = { (indexes: [Any]?, names: [Any]?) in
            self.trackList(indexes: indexes, names: names).filter { $0.0 != -1 }.map {
                TrackLanguage.Track(id: $0.0, name: $0.1, language: languages[$0.0])
            }
        }
        let audio = tracks(player.audioTrackIndexes, player.audioTrackNames)
        if audio.count > 1, let id = TrackLanguage.pick(audio, preferred: info.audioLanguages) {
            player.currentAudioTrackIndex = id
            Log.player.info("picked audio track \(id) for \(info.audioLanguages, privacy: .public)")
        }
        let subs = tracks(player.videoSubTitlesIndexes, player.videoSubTitlesNames)
        if let id = TrackLanguage.pick(subs, preferred: info.subtitleLanguages) {
            selectedExternalSubtitle = nil
            player.currentVideoSubTitleIndex = id
            Log.player.info("picked subtitle track \(id) for \(info.subtitleLanguages, privacy: .public)")
            return
        }
        let online = playback.externalSubtitles
        let onlineTracks = online.enumerated().map { TrackLanguage.Track(id: Int32($0), name: "", language: $1.lang) }
        if let index = TrackLanguage.pick(onlineTracks, preferred: info.subtitleLanguages) {
            let sub = online[Int(index)]
            player.addPlaybackSlave(sub.url, type: .subtitle, enforce: true)
            selectedExternalSubtitle = sub.url
            Log.player.info("picked online subtitles \(sub.lang, privacy: .public)")
        }
    }

    /// The language code of each track, by track ID.
    private func trackLanguages() -> [Int32: String] {
        var result: [Int32: String] = [:]
        for case let track as [String: Any] in player?.media?.tracksInformation ?? [] {
            guard let id = (track[VLCMediaTracksInformationId] as? NSNumber)?.int32Value,
                let language = track[VLCMediaTracksInformationLanguage] as? String
            else { continue }
            result[id] = language
        }
        return result
    }

    func applySubtitleSize(_ size: SubtitleSize) {
        // VLCKit 3 implements this setter but leaves it out of its public headers.
        let selector = NSSelectorFromString("setTextRendererFontSize:")
        guard let player, player.responds(to: selector) else {
            Log.player.error("VLC has no setTextRendererFontSize:, subtitle size not applied")
            return
        }
        player.perform(selector, with: NSNumber(value: size.rawValue))
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
