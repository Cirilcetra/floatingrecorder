import Foundation
import os

// MARK: - File-backed diagnostics (full session history)

enum FileLogger {
    private static let queue = DispatchQueue(label: "com.ceteralabs.FloatingRecorder.filelog")
    private static let maxBytes: Int64 = 5_000_000
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static var logDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("FloatingRecorder", isDirectory: true)
        return dir
    }

    static var logFileURL: URL {
        logDirectoryURL.appendingPathComponent("FloatingRecorder.log", isDirectory: false)
    }

    /// Call once early in launch so the folder exists and the first line records boot context.
    static func recordLaunchBanner(axTrusted: Bool) {
        let bid = Bundle.main.bundleIdentifier ?? "(nil)"
        let bundlePath = Bundle.main.bundleURL.path
        let ax = axTrusted ? "yes" : "no"
        let pid = ProcessInfo.processInfo.processIdentifier
        appendRaw("----- launch pid=\(pid) bundleId=\(bid) AXTrusted=\(ax) bundlePath=\(bundlePath) -----")
    }

    static func append(level: String, category: String, _ message: String) {
        let line = "[\(level)] [\(category)] \(message)"
        appendRaw(line)
    }

    /// Ensures the last line hits disk before the process exits (async queue would often drop it).
    static func syncWriteTerminationNotice() {
        queue.sync {
            writeLineToDisk("----- applicationWillTerminate -----")
        }
    }

    private static func appendRaw(_ line: String) {
        queue.async {
            writeLineToDisk(line)
        }
    }

    private static func writeLineToDisk(_ line: String) {
        do {
            try FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
            let url = logFileURL
            let stamp = isoFormatter.string(from: Date())
            let data = Data("\(stamp) \(line)\n".utf8)

            if FileManager.default.fileExists(atPath: url.path) {
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                if size + Int64(data.count) > maxBytes {
                    let rotated = url.deletingLastPathComponent().appendingPathComponent("FloatingRecorder.log.1")
                    try? FileManager.default.removeItem(at: rotated)
                    try FileManager.default.moveItem(at: url, to: rotated)
                }
            }

            if FileManager.default.fileExists(atPath: url.path) {
                let h = try FileHandle(forWritingTo: url)
                try h.seekToEnd()
                try h.write(contentsOf: data)
                try h.close()
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            fputs("FileLogger: \(error.localizedDescription)\n", stderr)
        }
    }
}

// MARK: - Dual sink: unified logging + OSLog

struct AppLogger {
    fileprivate let category: String
    private let osLogger: Logger

    init(category: String, subsystem: String) {
        self.category = category
        self.osLogger = Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .public)")
        FileLogger.append(level: "DEBUG", category: category, message)
    }

    func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        FileLogger.append(level: "INFO", category: category, message)
    }

    func notice(_ message: String) {
        osLogger.notice("\(message, privacy: .public)")
        FileLogger.append(level: "NOTICE", category: category, message)
    }

    func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        FileLogger.append(level: "ERROR", category: category, message)
    }
}

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.ceteralabs.FloatingRecorder"

    static let app = AppLogger(category: "app", subsystem: subsystem)
    static let audio = AppLogger(category: "audio", subsystem: subsystem)
    static let whisper = AppLogger(category: "whisper", subsystem: subsystem)
    static let hotkey = AppLogger(category: "hotkey", subsystem: subsystem)
    static let ui = AppLogger(category: "ui", subsystem: subsystem)
    static let models = AppLogger(category: "models", subsystem: subsystem)
    static let paste = AppLogger(category: "paste", subsystem: subsystem)
}
