import Foundation

/// JavaScript files bundled under Resources/JS.
enum UserScripts {
    static func url(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "js")
    }

    static func source(named name: String) -> String {
        guard let url = url(named: name), let source = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing bundled script \(name).js")
            return ""
        }
        return source
    }
}
