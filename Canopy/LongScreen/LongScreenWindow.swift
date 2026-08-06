import AppKit

final class LongScreenWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: false)
        // .screenSaver — needs to be a true full-screen takeover, above menu bar
        // extras and other floating system overlays. macOS keeps its own security/
        // permission prompts above even the real screensaver, so this doesn't risk
        // hiding those.
        level = .screenSaver
        isOpaque = true
        backgroundColor = .black
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        hasShadow = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
}
