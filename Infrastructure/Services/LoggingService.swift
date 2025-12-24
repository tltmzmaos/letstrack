import Foundation
import os.log

// MARK: - Log Level

enum LogLevel: String, Codable, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

// MARK: - Log Entry

struct LogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let file: String
    let function: String
    let line: Int
    var metadata: [String: String]?

    init(
        level: LogLevel,
        category: String,
        message: String,
        file: String,
        function: String,
        line: Int,
        metadata: [String: String]? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
        self.metadata = metadata
    }

    var formattedString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timeString = dateFormatter.string(from: timestamp)

        var result = "\(level.emoji) [\(timeString)] [\(level.rawValue)] [\(category)] \(message)"
        result += "\n   📍 \(file):\(line) - \(function)"

        if let metadata = metadata, !metadata.isEmpty {
            let metaString = metadata.map { "   • \($0.key): \($0.value)" }.joined(separator: "\n")
            result += "\n\(metaString)"
        }

        return result
    }
}

// MARK: - Logging Service

final class LoggingService {
    static let shared = LoggingService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.letstrack", category: "App")
    private var logs: [LogEntry] = []
    private let maxLogCount = 1000
    private let queue = DispatchQueue(label: "com.letstrack.logging", qos: .utility)
    private let logFileURL: URL

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFileURL = documentsPath.appendingPathComponent("letstrack_logs.json")
        loadLogs()
    }

    // MARK: - Public Methods

    func debug(
        _ message: String,
        category: String = "General",
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func info(
        _ message: String,
        category: String = "General",
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func warning(
        _ message: String,
        category: String = "General",
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func error(
        _ message: String,
        category: String = "General",
        error: Error? = nil,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var meta = metadata ?? [:]
        if let error = error {
            meta["error_description"] = error.localizedDescription
            meta["error_type"] = String(describing: type(of: error))
        }
        log(level: .error, message: message, category: category, metadata: meta, file: file, function: function, line: line)
    }

    // MARK: - Log Retrieval

    func getAllLogs() -> [LogEntry] {
        queue.sync { logs }
    }

    func getLogs(level: LogLevel? = nil, category: String? = nil, limit: Int? = nil) -> [LogEntry] {
        queue.sync {
            var filtered = logs

            if let level = level {
                filtered = filtered.filter { $0.level == level }
            }

            if let category = category {
                filtered = filtered.filter { $0.category == category }
            }

            if let limit = limit {
                filtered = Array(filtered.suffix(limit))
            }

            return filtered
        }
    }

    func getRecentLogs(count: Int = 100) -> [LogEntry] {
        queue.sync {
            Array(logs.suffix(count))
        }
    }

    func clearLogs() {
        queue.async { [weak self] in
            self?.logs.removeAll()
            self?.saveLogs()
        }
    }

    // MARK: - Report Generation

    func generateReport() -> String {
        let logs = getAllLogs()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var report = """
        ═══════════════════════════════════════════════════════════════
                            LetsTrack Diagnostic Report
        ═══════════════════════════════════════════════════════════════

        Generated: \(dateFormatter.string(from: Date()))
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
        Device: \(deviceInfo())
        iOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)

        ───────────────────────────────────────────────────────────────
                                    Summary
        ───────────────────────────────────────────────────────────────

        Total Logs: \(logs.count)
        Errors: \(logs.filter { $0.level == .error }.count)
        Warnings: \(logs.filter { $0.level == .warning }.count)
        Info: \(logs.filter { $0.level == .info }.count)
        Debug: \(logs.filter { $0.level == .debug }.count)

        ───────────────────────────────────────────────────────────────
                                  Recent Logs
        ───────────────────────────────────────────────────────────────

        """

        let recentLogs = Array(logs.suffix(50))
        for log in recentLogs {
            report += "\n\(log.formattedString)\n"
        }

        report += """

        ═══════════════════════════════════════════════════════════════
                              End of Report
        ═══════════════════════════════════════════════════════════════
        """

        return report
    }

    func generateReportData() -> Data? {
        generateReport().data(using: .utf8)
    }

    // MARK: - Private Methods

    private func log(
        level: LogLevel,
        message: String,
        category: String,
        metadata: [String: String]?,
        file: String,
        function: String,
        line: Int
    ) {
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: metadata
        )

        // Log to system console
        logger.log(level: level.osLogType, "\(entry.formattedString)")

        // Store in memory and file
        queue.async { [weak self] in
            guard let self = self else { return }
            self.logs.append(entry)

            // Trim if exceeds max
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            self.saveLogs()
        }
    }

    private func saveLogs() {
        do {
            let data = try JSONEncoder().encode(logs)
            try data.write(to: logFileURL)
        } catch {
            print("Failed to save logs: \(error)")
        }
    }

    private func loadLogs() {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try Data(contentsOf: self.logFileURL)
                self.logs = try JSONDecoder().decode([LogEntry].self, from: data)
            } catch {
                self.logs = []
            }
        }
    }

    private func deviceInfo() -> String {
        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #endif
    }
}

// MARK: - Convenience Global Functions

func logDebug(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, error: Error? = nil, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.error(message, category: category, error: error, file: file, function: function, line: line)
}
