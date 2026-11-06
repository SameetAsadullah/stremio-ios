import os

enum Log {
    private static let subsystem = "com.sameetasadullah.stremio"

    static let web = Logger(subsystem: subsystem, category: "web")
    static let player = Logger(subsystem: subsystem, category: "player")
    static let server = Logger(subsystem: subsystem, category: "server")
    static let proxy = Logger(subsystem: subsystem, category: "proxy")
    static let tv = Logger(subsystem: subsystem, category: "tv")
}
