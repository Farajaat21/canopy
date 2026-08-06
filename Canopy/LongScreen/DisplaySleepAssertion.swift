import IOKit.pwr_mgt

/// Keeps the display awake while the long-screen view is up, so it behaves like a
/// real screensaver replacement instead of going dark mid-song.
final class DisplaySleepAssertion {
    private var assertionID: IOPMAssertionID = 0
    private var isActive = false

    func acquire(reason: String) {
        guard !isActive else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        isActive = result == kIOReturnSuccess
    }

    func release() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        isActive = false
    }

    deinit {
        if isActive {
            IOPMAssertionRelease(assertionID)
        }
    }
}
