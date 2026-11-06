import Foundation

/// Subtitle text size. VLC sizes subtitle text relative to the video height and the raw value
/// is the divisor, so a smaller value gives larger text.
enum SubtitleSize: Int, CaseIterable {
    case small = 20
    case normal = 16
    case large = 12
    case extraLarge = 9

    var title: String {
        switch self {
        case .small: return "Small"
        case .normal: return "Normal"
        case .large: return "Large"
        case .extraLarge: return "Extra large"
        }
    }

    static let defaultsKey = "subtitleSize"

    static func saved(in defaults: UserDefaults = .standard) -> SubtitleSize {
        SubtitleSize(rawValue: defaults.integer(forKey: defaultsKey)) ?? .normal
    }

    func save(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}
