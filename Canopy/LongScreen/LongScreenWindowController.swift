import AppKit
import SwiftUI
import os.log

@MainActor
final class LongScreenWindowController {
    static let shared = LongScreenWindowController()

    private(set) var isShowing = false

    private var windows: [LongScreenWindow] = []
    private var dismissMonitor: Any?
    private var shownAt: Date?
    private let displaySleepAssertion = DisplaySleepAssertion()
    private let log = Logger(subsystem: "dev.canopy.app", category: "LongScreen")

    /// The keypress that opens the long screen (hotkey) can itself be observed by the
    /// dismiss monitor a moment later, instantly closing what just opened. Ignore
    /// dismiss events within this grace window after showing.
    private let dismissGracePeriod: TimeInterval = 0.5

    private init() {}

    func show(reason: String = "unknown") {
        guard !isShowing else {
            log.debug("show(\(reason, privacy: .public)) ignored, already showing")
            return
        }
        isShowing = true
        shownAt = Date()
        log.debug("Showing long screen across \(NSScreen.screens.count) screen(s), reason=\(reason, privacy: .public)")

        windows = NSScreen.screens.map { screen in
            let window = LongScreenWindow(screen: screen)
            let content = LongScreenView(onClose: { [weak self] in
                self?.hide(reason: "close-button")
            })
            window.contentView = NSHostingView(rootView: content)
            window.makeKeyAndOrderFront(nil)
            return window
        }

        NSApp.activate(ignoringOtherApps: true)

        // Only keyDown auto-dismisses (like a real screensaver responding to "any key").
        // Mouse movement/clicks must NOT dismiss, since the view has real buttons on it —
        // moving the cursor toward a button would otherwise close the window before the
        // click could land. Clicking away is handled by the explicit close button.
        dismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if let shownAt = self.shownAt, Date().timeIntervalSince(shownAt) < self.dismissGracePeriod {
                return event
            }
            self.log.debug("Dismiss monitor caught keyDown")
            self.hide(reason: "keyDown")
            return event
        }

        displaySleepAssertion.acquire(reason: "Canopy long-screen lyrics")
    }

    func hide(reason: String = "unknown") {
        guard isShowing else { return }
        isShowing = false
        log.debug("Hiding long screen, reason=\(reason, privacy: .public)")

        if let dismissMonitor {
            NSEvent.removeMonitor(dismissMonitor)
        }
        dismissMonitor = nil

        windows.forEach { $0.orderOut(nil) }
        windows = []

        displaySleepAssertion.release()
        NSApp.setActivationPolicy(.accessory)
    }

    func toggle(reason: String = "unknown") {
        log.debug("toggle(\(reason, privacy: .public)) called, isShowing=\(self.isShowing)")
        if isShowing {
            hide(reason: reason)
        } else {
            show(reason: reason)
        }
    }
}
