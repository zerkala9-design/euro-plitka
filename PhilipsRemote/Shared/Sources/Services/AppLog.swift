import Foundation
import os

/// Central logging layer built on `os.Logger`.
///
/// A ring buffer of recent entries is kept for the in‑app Command Log /
/// Diagnostics export. Sensitive values (tokens, PINs) are never logged.
public actor AppLog {
    public static let shared = AppLog()

    public struct Entry: Identifiable, Codable, Sendable {
        public var id = UUID()
        public var date = Date()
        public var category: String
        public var level: String
        public var message: String
    }

    private let subsystem = "com.europlitka.philipsremote"
    private var loggers: [String: Logger] = [:]
    private var buffer: [Entry] = []
    private let bufferLimit = 500

    private func logger(for category: String) -> Logger {
        if let l = loggers[category] { return l }
        let l = Logger(subsystem: subsystem, category: category)
        loggers[category] = l
        return l
    }

    public func log(_ message: String, category: String = "general", level: OSLogType = .default) {
        logger(for: category).log(level: level, "\(message, privacy: .public)")
        let entry = Entry(category: category, level: level.name, message: message)
        buffer.append(entry)
        if buffer.count > bufferLimit { buffer.removeFirst(buffer.count - bufferLimit) }
    }

    public func debug(_ m: String, category: String = "general") { log(m, category: category, level: .debug) }
    public func info(_ m: String, category: String = "general")  { log(m, category: category, level: .info) }
    public func error(_ m: String, category: String = "general") { log(m, category: category, level: .error) }

    public func recentEntries() -> [Entry] { buffer }
    public func clear() { buffer.removeAll() }

    /// Newline delimited plain text export of the command/reconnect log.
    public func exportText() -> String {
        let df = ISO8601DateFormatter()
        return buffer.map { "\(df.string(from: $0.date)) [\($0.level.uppercased())] \($0.category): \($0.message)" }
            .joined(separator: "\n")
    }
}

private extension OSLogType {
    var name: String {
        switch self {
        case .debug: return "debug"
        case .info: return "info"
        case .error: return "error"
        case .fault: return "fault"
        default: return "default"
        }
    }
}
