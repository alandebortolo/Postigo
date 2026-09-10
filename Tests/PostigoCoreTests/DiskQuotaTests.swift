import XCTest
@testable import PostigoCore

final class DiskQuotaTests: XCTestCase {
    func testUnderQuotaKeepsEverything() {
        let files = [
            file("a.mp4", bytes: 100, age: 10, protected: false),
            file("b_motion.mp4", bytes: 100, age: 5, protected: true),
        ]
        let result = DiskQuota.enforce(
            files: files,
            quotaBytes: 1000,
            maxAge: 3600,
            warnPercent: 80,
            now: Date(timeIntervalSince1970: 1000)
        )
        XCTAssertTrue(result.deleted.isEmpty)
        XCTAssertEqual(result.usedBytes, 200)
        XCTAssertFalse(result.stillOverQuota)
        XCTAssertFalse(result.warn)
    }

    func testDeletesOldestNonProtectedFirst() {
        let files = [
            file("old.mp4", bytes: 400, age: 50, protected: false),
            file("mid.mp4", bytes: 400, age: 20, protected: false),
            file("keep_motion.mp4", bytes: 400, age: 5, protected: true),
        ]
        let result = DiskQuota.enforce(
            files: files,
            quotaBytes: 500,
            maxAge: 3600,
            warnPercent: 80,
            now: Date(timeIntervalSince1970: 1000)
        )
        XCTAssertEqual(result.deleted.map(\.lastPathComponent).sorted(), ["mid.mp4", "old.mp4"])
        XCTAssertEqual(result.usedBytes, 400)
        XCTAssertFalse(result.stillOverQuota)
    }

    func testDoesNotDeleteRecentProtectedToFreeQuota() {
        let files = [
            file("a_motion.mp4", bytes: 800, age: 10, protected: true),
            file("b_preroll.mp4", bytes: 800, age: 8, protected: true),
        ]
        let result = DiskQuota.enforce(
            files: files,
            quotaBytes: 500,
            maxAge: 3600,
            warnPercent: 80,
            now: Date(timeIntervalSince1970: 1000)
        )
        XCTAssertTrue(result.deleted.isEmpty)
        XCTAssertTrue(result.stillOverQuota)
        XCTAssertEqual(result.usedBytes, 1600)
    }

    func testRetentionDeletesExpiredProtected() {
        let now = Date(timeIntervalSince1970: 10_000)
        let files = [
            file("old_motion.mp4", bytes: 100, age: 5000, protected: true, now: now),
            file("fresh_motion.mp4", bytes: 100, age: 10, protected: true, now: now),
        ]
        let result = DiskQuota.enforce(
            files: files,
            quotaBytes: 10_000,
            maxAge: 100,
            warnPercent: 80,
            now: now
        )
        XCTAssertEqual(result.deleted.map(\.lastPathComponent), ["old_motion.mp4"])
        XCTAssertEqual(result.usedBytes, 100)
    }

    func testWarnAtEightyPercent() {
        let files = [file("a.mp4", bytes: 81, age: 1, protected: false)]
        let result = DiskQuota.enforce(
            files: files,
            quotaBytes: 100,
            maxAge: 3600,
            warnPercent: 80,
            now: Date(timeIntervalSince1970: 50)
        )
        XCTAssertTrue(result.warn)
        XCTAssertFalse(result.stillOverQuota)
    }

    func testNamerMarksProtected() {
        XCTAssertTrue(RecordingNamer.isProtected(fileName: "x_motion.mp4"))
        XCTAssertTrue(RecordingNamer.isProtected(fileName: "x_preroll.mp4"))
        XCTAssertTrue(RecordingNamer.isProtected(fileName: "x.jpg"))
        XCTAssertFalse(RecordingNamer.isProtected(fileName: "x.mp4"))
    }

    func testFileNameFormat() {
        let date = Date(timeIntervalSince1970: 0)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let name = RecordingNamer.fileName(date: date, kind: .motion)
        XCTAssertTrue(name.hasSuffix("_motion.mp4"))
        XCTAssertEqual(name.count, "yyyy-MM-ddTHHmmss_motion.mp4".count)
    }

    func testPowerStopOnlyOnBattery() {
        XCTAssertFalse(PowerState(isAC: true, percent: 5).shouldStop(thresholdPercent: 10))
        XCTAssertTrue(PowerState(isAC: false, percent: 9).shouldStop(thresholdPercent: 10))
        XCTAssertFalse(PowerState(isAC: false, percent: 11).shouldStop(thresholdPercent: 10))
        XCTAssertFalse(PowerState(isAC: false, percent: nil).shouldStop(thresholdPercent: 10))
    }

    func testBrandName() {
        XCTAssertEqual(Brand.name, "Postigo")
        XCTAssertEqual(Brand.folderName, "Postigo")
    }

    func testPreferencesPINSanitizes() {
        var p = Preferences(pin: "12ab")
        XCTAssertEqual(p.sanitizedPIN, "1234")
        p.pin = "9876"
        XCTAssertEqual(p.sanitizedPIN, "9876")
    }

    func testDefaultQuotaIsTenGB() {
        XCTAssertEqual(Preferences().quotaBytes, 10_000_000_000)
    }

    func testStoreMigratesOldFiveGBDefaultOnce() {
        let defaults = UserDefaults(suiteName: "postigo.test.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(Preferences(quotaBytes: 5_000_000_000, pin: "1234"))
        XCTAssertEqual(store.load().quotaBytes, 10_000_000_000)
        store.save(Preferences(quotaBytes: 5_000_000_000, pin: "1234"))
        XCTAssertEqual(store.load().quotaBytes, 5_000_000_000)
    }

    func testStoreKeepsPINUntilFourDigits() {
        let defaults = UserDefaults(suiteName: "postigo.test.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(Preferences(pin: "1234"))
        store.save(Preferences(pin: "9"))
        XCTAssertEqual(store.load().pin, "1234")
        store.save(Preferences(pin: "9876"))
        XCTAssertEqual(store.load().pin, "9876")
    }

    func testEventLogRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let log = EventLog(root: dir)
        log.append(LogEvent(kind: .recordStart, detail: "keepAll"))
        log.append(LogEvent(kind: .motion, detail: "score=0.2"))
        let text = log.formatted()
        XCTAssertTrue(text.contains("recordStart"))
        XCTAssertTrue(text.contains("motion"))
    }

    private func file(
        _ name: String,
        bytes: Int64,
        age: TimeInterval,
        protected: Bool,
        now: Date = Date(timeIntervalSince1970: 1000)
    ) -> RecordingFile {
        RecordingFile(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            bytes: bytes,
            modified: now.addingTimeInterval(-age),
            protected: protected
        )
    }
}
