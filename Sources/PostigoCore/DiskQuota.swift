import Foundation

public struct RecordingFile: Equatable {
    public var url: URL
    public var bytes: Int64
    public var modified: Date
    public var protected: Bool

    public init(url: URL, bytes: Int64, modified: Date, protected: Bool) {
        self.url = url
        self.bytes = bytes
        self.modified = modified
        self.protected = protected
    }
}

public struct QuotaResult: Equatable {
    public var usedBytes: Int64
    public var deleted: [URL]
    public var stillOverQuota: Bool
    public var warn: Bool

    public init(usedBytes: Int64, deleted: [URL], stillOverQuota: Bool, warn: Bool) {
        self.usedBytes = usedBytes
        self.deleted = deleted
        self.stillOverQuota = stillOverQuota
        self.warn = warn
    }
}

public enum DiskQuota {
    /// Deletes expired files first (non-protected, then protected). If still over the
    /// byte quota, deletes oldest non-protected. Never deletes recent protected clips
    /// just to free space — the caller should stop recording instead.
    public static func enforce(
        files: [RecordingFile],
        quotaBytes: Int64,
        maxAge: TimeInterval,
        warnPercent: Int,
        now: Date = Date()
    ) -> QuotaResult {
        var remaining = files.sorted { $0.modified < $1.modified }
        var deleted: [URL] = []

        func drop(_ file: RecordingFile) {
            remaining.removeAll { $0.url == file.url }
            deleted.append(file.url)
        }

        let expired = remaining.filter { now.timeIntervalSince($0.modified) > maxAge }
        for file in expired where !file.protected {
            drop(file)
        }
        for file in remaining where now.timeIntervalSince(file.modified) > maxAge {
            drop(file)
        }

        func used() -> Int64 { remaining.reduce(0) { $0 + $1.bytes } }

        if used() > quotaBytes {
            for file in remaining where !file.protected {
                if used() <= quotaBytes { break }
                drop(file)
            }
        }

        let usedBytes = used()
        let warn = quotaBytes > 0 && usedBytes * 100 >= quotaBytes * Int64(warnPercent)
        return QuotaResult(
            usedBytes: usedBytes,
            deleted: deleted,
            stillOverQuota: usedBytes > quotaBytes,
            warn: warn
        )
    }

    public static func scan(root: URL) -> [RecordingFile] {
        let fm = FileManager.default
        let folders = [
            root.appendingPathComponent("Recordings", isDirectory: true),
            root.appendingPathComponent("Snapshots", isDirectory: true),
            root.appendingPathComponent("Temp", isDirectory: true),
        ]
        var out: [RecordingFile] = []
        for folder in folders {
            guard let items = try? fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in items {
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                let bytes = Int64(values?.fileSize ?? 0)
                let modified = values?.contentModificationDate ?? Date.distantPast
                out.append(RecordingFile(
                    url: url,
                    bytes: bytes,
                    modified: modified,
                    protected: RecordingNamer.isProtected(fileName: url.lastPathComponent)
                ))
            }
        }
        return out
    }
}
