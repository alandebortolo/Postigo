import Foundation

public struct Preferences: Codable, Equatable {
    public var quotaBytes: Int64
    public var retentionHours: Int
    public var width: Int
    public var height: Int
    public var fps: Int32
    public var bitrate: Int
    public var pin: String
    public var keepAllWhenManual: Bool
    public var motionOnlyWhenAway: Bool
    public var motionThreshold: Float
    public var cameraUniqueID: String?
    public var openAtLogin: Bool
    public var manualSegmentSeconds: Int
    public var motionSegmentSeconds: Int
    public var trailingSeconds: Int
    public var snapshotEveryMotionSeconds: Int
    public var batteryStopPercent: Int
    public var quotaWarnPercent: Int
    public var recordingsRootPath: String?

    public init(
        quotaBytes: Int64 = 10_000_000_000,
        retentionHours: Int = 48,
        width: Int = 1280,
        height: Int = 720,
        fps: Int32 = 15,
        bitrate: Int = 800_000,
        pin: String = "1234",
        keepAllWhenManual: Bool = true,
        motionOnlyWhenAway: Bool = true,
        motionThreshold: Float = 0.045,
        cameraUniqueID: String? = nil,
        openAtLogin: Bool = false,
        manualSegmentSeconds: Int = 300,
        motionSegmentSeconds: Int = 20,
        trailingSeconds: Int = 10,
        snapshotEveryMotionSeconds: Int = 5,
        batteryStopPercent: Int = 10,
        quotaWarnPercent: Int = 80,
        recordingsRootPath: String? = nil
    ) {
        self.quotaBytes = quotaBytes
        self.retentionHours = retentionHours
        self.width = width
        self.height = height
        self.fps = fps
        self.bitrate = bitrate
        self.pin = pin
        self.keepAllWhenManual = keepAllWhenManual
        self.motionOnlyWhenAway = motionOnlyWhenAway
        self.cameraUniqueID = cameraUniqueID
        self.openAtLogin = openAtLogin
        self.motionThreshold = motionThreshold
        self.manualSegmentSeconds = manualSegmentSeconds
        self.motionSegmentSeconds = motionSegmentSeconds
        self.trailingSeconds = trailingSeconds
        self.snapshotEveryMotionSeconds = snapshotEveryMotionSeconds
        self.batteryStopPercent = batteryStopPercent
        self.quotaWarnPercent = quotaWarnPercent
        self.recordingsRootPath = recordingsRootPath
    }

    public var sanitizedPIN: String {
        let digits = pin.filter(\.isNumber)
        if digits.count == 4 { return digits }
        return "1234"
    }

    public var quotaGigabytes: Double {
        Double(quotaBytes) / 1_000_000_000.0
    }

    public static func defaultRoot() -> URL {
        Brand.defaultRoot()
    }

    public func resolvedRoot() -> URL {
        if let recordingsRootPath, !recordingsRootPath.isEmpty {
            return URL(fileURLWithPath: recordingsRootPath, isDirectory: true)
        }
        return Self.defaultRoot()
    }
}

public final class PreferencesStore {
    public static let defaultsKey = "deskcam.preferences.v1"
    public static let quota10GBMigrationKey = "deskcam.quota.migrated.10gb"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Preferences {
        guard let data = defaults.data(forKey: Self.defaultsKey) else {
            return Preferences()
        }
        do {
            var prefs = try JSONDecoder().decode(Preferences.self, from: data)
            if defaults.object(forKey: Self.quota10GBMigrationKey) == nil {
                if prefs.quotaBytes == 5_000_000_000 {
                    prefs.quotaBytes = 10_000_000_000
                    save(prefs)
                }
                defaults.set(true, forKey: Self.quota10GBMigrationKey)
            }
            return prefs
        } catch {
            return Preferences()
        }
    }

    public func save(_ prefs: Preferences) {
        var copy = prefs
        let digits = copy.pin.filter(\.isNumber)
        if digits.count == 4 {
            copy.pin = digits
        } else {
            copy.pin = load().sanitizedPIN
        }
        if let data = try? JSONEncoder().encode(copy) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
