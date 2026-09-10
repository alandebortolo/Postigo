import Foundation
import IOKit.ps

public struct PowerState: Equatable {
    public var isAC: Bool
    public var percent: Int?

    public init(isAC: Bool, percent: Int?) {
        self.isAC = isAC
        self.percent = percent
    }

    public func shouldStop(thresholdPercent: Int) -> Bool {
        guard !isAC, let percent else { return false }
        return percent <= thresholdPercent
    }
}

public enum PowerInfo {
    public static func current() -> PowerState {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return PowerState(isAC: true, percent: nil)
        }

        var percent: Int?
        var isAC = true
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let cap = desc[kIOPSCurrentCapacityKey] as? Int {
                percent = cap
            }
            if let state = desc[kIOPSPowerSourceStateKey] as? String {
                isAC = state == kIOPSACPowerValue
            }
        }
        return PowerState(isAC: isAC, percent: percent)
    }
}
