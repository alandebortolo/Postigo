import Foundation

public enum EventKind: String, Codable, Equatable {
    case launched
    case crashRecovered
    case recordStart
    case recordStop
    case awayStart
    case awayWake
    case awayFailsafe
    case motion
    case motionEnd
    case intrusion
    case pinFail
    case quotaWarn
    case quotaStop
    case cameraError
    case note
}

public struct LogEvent: Codable, Equatable {
    public var ts: Date
    public var kind: EventKind
    public var detail: String

    public init(ts: Date = Date(), kind: EventKind, detail: String = "") {
        self.ts = ts
        self.kind = kind
        self.detail = detail
    }
}

public final class EventLog {
    public let url: URL
    private let lock = NSLock()
    private static let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    public init(root: URL) {
        self.url = root.appendingPathComponent("events.jsonl")
    }

    public func append(_ event: LogEvent) {
        lock.lock()
        defer { lock.unlock() }
        let ts = Self.stamp.string(from: event.ts)
        let detail = event.detail.replacingOccurrences(of: "\n", with: " ")
        let line = "{\"ts\":\"\(ts)\",\"kind\":\"\(event.kind.rawValue)\",\"detail\":\(jsonString(detail))}\n"
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        if let data = line.data(using: .utf8) {
            try? handle.write(contentsOf: data)
        }
        trimIfNeeded()
    }

    public func recent(limit: Int = 200) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return []
        }
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        return Array(lines.suffix(limit))
    }

    public func formatted(limit: Int = 200) -> String {
        recent(limit: limit).joined(separator: "\n")
    }

    private func trimIfNeeded() {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return }
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 2500 else { return }
        let kept = lines.suffix(2000).joined(separator: "\n") + "\n"
        try? kept.write(to: url, atomically: true, encoding: String.Encoding.utf8)
    }

    private func jsonString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
