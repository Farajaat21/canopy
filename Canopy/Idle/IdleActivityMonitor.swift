import CoreGraphics
import Foundation
import os.log

/// Tracks system-wide idle time (independent of which app is focused) and fires once
/// when the idle threshold is crossed, and again when the user becomes active.
@MainActor
final class IdleActivityMonitor {
    var idleThreshold: TimeInterval
    var onIdleStart: (() -> Void)?
    var onIdleEnd: (() -> Void)?

    private var timer: Timer?
    private var isIdle = false
    private let log = Logger(subsystem: "dev.canopy.app", category: "Idle")

    init(idleThreshold: TimeInterval = IdleActivityMonitor.systemScreenSaverDelay()) {
        self.idleThreshold = idleThreshold
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)

        if idleSeconds >= idleThreshold {
            guard !isIdle else { return }
            isIdle = true
            log.debug("Idle threshold crossed (\(idleSeconds, format: .fixed(precision: 0))s)")
            onIdleStart?()
        } else {
            guard isIdle else { return }
            isIdle = false
            log.debug("User active again")
            onIdleEnd?()
        }
    }

    /// Reads the user's configured screensaver idle delay so our long-screen view can
    /// take over shortly before the system screensaver would otherwise kick in.
    /// Falls back to 5 minutes if unavailable.
    nonisolated static func systemScreenSaverDelay() -> TimeInterval {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["-currentHost", "read", "com.apple.screensaver", "idleTime"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let seconds = TimeInterval(text), seconds > 0 {
                return max(15, seconds - 5)
            }
        } catch {
            // Fall through to the default below.
        }
        return 300
    }
}
