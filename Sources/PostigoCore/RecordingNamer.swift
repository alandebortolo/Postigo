import Foundation

public enum ClipKind: String, Equatable {
    case continuous
    case motion
    case preroll
    case snapshot
}

public enum RecordingNamer {
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd'T'HHmmss"
        return f
    }()

    public static func fileName(date: Date, kind: ClipKind) -> String {
        let base = stamp.string(from: date)
        switch kind {
        case .continuous:
            return "\(base).mp4"
        case .motion:
            return "\(base)_motion.mp4"
        case .preroll:
            return "\(base)_preroll.mp4"
        case .snapshot:
            return "\(base).jpg"
        }
    }

    public static func isProtected(fileName: String) -> Bool {
        fileName.contains("_motion") || fileName.contains("_preroll") || fileName.hasSuffix(".jpg")
    }
}
