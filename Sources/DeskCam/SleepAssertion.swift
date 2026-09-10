import Foundation
import IOKit.pwr_mgt

final class SleepAssertion {
    private var assertionID: IOPMAssertionID = 0
    private var activity: NSObjectProtocol?

    func take() {
        if assertionID == 0 {
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoIdleSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "DeskCam recording" as CFString,
                &assertionID
            )
        }
        if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled, .idleDisplaySleepDisabled],
                reason: "DeskCam recording"
            )
        }
    }

    func release() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }
}
