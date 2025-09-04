import Foundation

/// Logging levels for NetworkInfo application
enum LogLevel: String, CaseIterable {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"  
    case warning = "⚠️ WARN"
    case error = "❌ ERROR"
    case notification = "📣 NOTIFY"
    
    var prefix: String { rawValue }
}

/// Centralized logging system for NetworkInfo
struct Logger {
    
    // MARK: - Configuration
    
    /// Current logging level - only messages at this level or higher will be printed
    static let logLevel: LogLevel = .info
    
    /// Whether to include timestamps in log output
    static let includeTimestamp = true
    
    // MARK: - Public Interface
    
    /// Log a message at the specified level
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The severity level (default: .info)
    ///   - category: Optional category for grouping (e.g., "DNS", "VPN", "GeoIP")
    static func log(_ message: String, level: LogLevel = .info, category: String? = nil) {
        guard shouldLog(level: level) else { return }
        
        var logMessage = level.prefix
        
        if includeTimestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            logMessage += " [\(formatter.string(from: Date()))]"
        }
        
        if let category = category {
            logMessage += " [\(category)]"
        }
        
        logMessage += " \(message)"
        
        print(logMessage)
    }
    
    // MARK: - Convenience Methods
    
    static func debug(_ message: String, category: String? = nil) {
        log(message, level: .debug, category: category)
    }
    
    static func info(_ message: String, category: String? = nil) {
        log(message, level: .info, category: category)
    }
    
    static func warning(_ message: String, category: String? = nil) {
        log(message, level: .warning, category: category)
    }
    
    static func error(_ message: String, category: String? = nil) {
        log(message, level: .error, category: category)
    }
    
    static func notification(_ message: String, category: String? = nil) {
        log(message, level: .notification, category: category)
    }
    
    // MARK: - Private Helpers
    
    private static func shouldLog(level: LogLevel) -> Bool {
        let levels: [LogLevel] = [.debug, .info, .warning, .error, .notification]
        guard let currentIndex = levels.firstIndex(of: logLevel),
              let messageIndex = levels.firstIndex(of: level) else {
            return true
        }
        return messageIndex >= currentIndex
    }
}