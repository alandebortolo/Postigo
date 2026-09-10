import CoreGraphics
import Foundation
import Darwin

final class BrightnessController {
    private var saved: [CGDirectDisplayID: Float] = [:]
    private var getFn: ((CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)?
    private var setFn: ((CGDirectDisplayID, Float) -> Int32)?
    private let flagURL: URL

    init(flagURL: URL) {
        self.flagURL = flagURL
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
            typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
            if let g = dlsym(handle, "DisplayServicesGetBrightness") {
                getFn = unsafeBitCast(g, to: GetFn.self)
            }
            if let s = dlsym(handle, "DisplayServicesSetBrightness") {
                setFn = unsafeBitCast(s, to: SetFn.self)
            }
        }
    }

    func recoverIfNeeded() {
        guard FileManager.default.fileExists(atPath: flagURL.path),
              let data = try? Data(contentsOf: flagURL),
              let map = try? JSONDecoder().decode([String: Float].self, from: data)
        else { return }
        for (key, value) in map {
            if let id = UInt32(key) {
                _ = setFn?(id, value)
            }
        }
        try? FileManager.default.removeItem(at: flagURL)
        saved.removeAll()
    }

    func dimAll() {
        saved.removeAll()
        for id in Self.displays() {
            var value: Float = 0
            if getFn?(id, &value) == 0 {
                saved[id] = value
                _ = setFn?(id, 0)
            }
        }
        persistFlag()
    }

    func restore() {
        for (id, value) in saved {
            _ = setFn?(id, value)
        }
        saved.removeAll()
        try? FileManager.default.removeItem(at: flagURL)
    }

    private func persistFlag() {
        var map: [String: Float] = [:]
        for (id, value) in saved {
            map[String(id)] = value
        }
        if let data = try? JSONEncoder().encode(map) {
            try? data.write(to: flagURL, options: .atomic)
        }
    }

    private static func displays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }
}
