import Foundation

struct LogEntry: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: Level
    let message: String

    init(level: Level = .info, message: String) {
        id = UUID()
        timestamp = .now
        self.level = level
        self.message = message
    }

    enum Level: String, Sendable {
        case info = "INFO"
        case success = "OK"
        case warning = "WARN"
        case error = "ERROR"
        case command = "CMD"
        case output = "OUT"

        var symbol: String {
            switch self {
            case .info: return "ℹ️"
            case .success: return "✅"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .command: return "⚙️"
            case .output: return "▶"
            }
        }
    }

    var formattedTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: timestamp)
    }
}
