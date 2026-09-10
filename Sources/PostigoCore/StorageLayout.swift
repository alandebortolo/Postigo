import Foundation

public struct StorageLayout: Equatable {
    public var root: URL

    public init(root: URL) {
        self.root = root
    }

    public var recordings: URL { root.appendingPathComponent("Recordings", isDirectory: true) }
    public var snapshots: URL { root.appendingPathComponent("Snapshots", isDirectory: true) }
    public var temp: URL { root.appendingPathComponent("Temp", isDirectory: true) }
    public var awayFlag: URL { root.appendingPathComponent(".away-active.json") }

    public func ensureFolders() throws {
        let fm = FileManager.default
        for url in [root, recordings, snapshots, temp] {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    public func newestRecording() -> URL? {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: recordings,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return items
            .filter { $0.pathExtension.lowercased() == "mp4" }
            .max { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da < db
            }
    }
}

public enum ByteFormat {
    public static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .decimal
        formatter.includesUnit = true
        return formatter.string(fromByteCount: bytes)
    }
}

public enum RunMode: String, Equatable {
    case idle
    case recording
    case away
}
