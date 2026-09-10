import XCTest
@testable import PostigoCore

final class MotionDetectorTests: XCTestCase {
    func testWarmupThenStillIsQuiet() {
        let detector = MotionDetector(threshold: 0.04, consecutiveNeeded: 3, trailing: 1, warmupFrames: 3)
        let black = Self.bgra(width: 320, height: 180, gray: 10)
        var last = MotionSample(score: 0, event: .none)
        for i in 0..<10 {
            last = black.withUnsafeBytes { raw in
                detector.push(
                    bgra: raw.baseAddress!,
                    width: 320,
                    height: 180,
                    bytesPerRow: 320 * 4,
                    now: Date(timeIntervalSince1970: Double(i))
                )
            }
        }
        XCTAssertEqual(last.event, .none)
        XCTAssertLessThan(last.score, 0.01)
    }

    func testJumpToWhiteStartsMotionAfterStreak() {
        let detector = MotionDetector(threshold: 0.04, consecutiveNeeded: 3, trailing: 10, warmupFrames: 4)
        let black = Self.bgra(width: 320, height: 180, gray: 8)
        let white = Self.bgra(width: 320, height: 180, gray: 240)
        for i in 0..<6 {
            _ = black.withUnsafeBytes { raw in
                detector.push(
                    bgra: raw.baseAddress!,
                    width: 320,
                    height: 180,
                    bytesPerRow: 320 * 4,
                    now: Date(timeIntervalSince1970: Double(i))
                )
            }
        }
        var events: [MotionEvent] = []
        for i in 6..<12 {
            let sample = white.withUnsafeBytes { raw in
                detector.push(
                    bgra: raw.baseAddress!,
                    width: 320,
                    height: 180,
                    bytesPerRow: 320 * 4,
                    now: Date(timeIntervalSince1970: Double(i))
                )
            }
            events.append(sample.event)
        }
        XCTAssertTrue(events.contains(.started), "events=\(events)")
        XCTAssertTrue(events.contains(.ongoing))
    }

    func testTrailingThenEnded() {
        let detector = MotionDetector(threshold: 0.04, consecutiveNeeded: 2, trailing: 2, warmupFrames: 2)
        let black = Self.bgra(width: 80, height: 40, gray: 5)
        let white = Self.bgra(width: 80, height: 40, gray: 250)
        for i in 0..<4 {
            _ = black.withUnsafeBytes { raw in
                detector.push(
                    bgra: raw.baseAddress!,
                    width: 80,
                    height: 40,
                    bytesPerRow: 80 * 4,
                    now: Date(timeIntervalSince1970: Double(i))
                )
            }
        }
        for i in 4..<8 {
            _ = white.withUnsafeBytes { raw in
                detector.push(
                    bgra: raw.baseAddress!,
                    width: 80,
                    height: 40,
                    bytesPerRow: 80 * 4,
                    now: Date(timeIntervalSince1970: Double(i))
                )
            }
        }
        var events: [MotionEvent] = []
        for i in 8..<14 {
            let sample = black.withUnsafeBytes { raw in
                detector.push(
                    bgra: raw.baseAddress!,
                    width: 80,
                    height: 40,
                    bytesPerRow: 80 * 4,
                    now: Date(timeIntervalSince1970: Double(i))
                )
            }
            events.append(sample.event)
        }
        XCTAssertTrue(events.contains(.ended), "events=\(events)")
    }

    func testClockSizedChangeOnTinyCornerDoesNotTripHighThreshold() {
        let detector = MotionDetector(threshold: 0.2, consecutiveNeeded: 3, trailing: 1, warmupFrames: 2)
        var frame = Self.bgra(width: 160, height: 90, gray: 20)
        for i in 0..<5 {
            _ = frame.withUnsafeBytes { raw in
                detector.push(
                    bgra: raw.baseAddress!,
                    width: 160,
                    height: 90,
                    bytesPerRow: 160 * 4,
                    now: Date(timeIntervalSince1970: Double(i))
                )
            }
        }
        // Flip a handful of pixels, like a timestamp digit — well under 0.2.
        for i in 0..<8 {
            frame[i] = 255
        }
        let sample = frame.withUnsafeBytes { raw in
            detector.push(
                bgra: raw.baseAddress!,
                width: 160,
                height: 90,
                bytesPerRow: 160 * 4,
                now: Date(timeIntervalSince1970: 10)
            )
        }
        XCTAssertEqual(sample.event, .none)
    }

    private static func bgra(width: Int, height: Int, gray: UInt8) -> [UInt8] {
        var data = [UInt8](repeating: 255, count: width * height * 4)
        for i in 0..<(width * height) {
            data[i * 4] = gray
            data[i * 4 + 1] = gray
            data[i * 4 + 2] = gray
        }
        return data
    }
}
