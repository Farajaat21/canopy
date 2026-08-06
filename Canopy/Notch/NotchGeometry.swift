import AppKit

struct NotchGeometry {
    /// Notch rect in global screen coordinates (bottom-left origin, matches NSScreen.frame).
    let frame: CGRect
    let isRealNotch: Bool

    private static let fallbackWidth: CGFloat = 200
    private static let fallbackHeight: CGFloat = 32

    static func detect(for screen: NSScreen) -> NotchGeometry {
        if let real = detectRealNotch(on: screen) {
            return real
        }
        return fallback(on: screen)
    }

    private static func detectRealNotch(on screen: NSScreen) -> NotchGeometry? {
        guard let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else { return nil }

        let topInset = screen.safeAreaInsets.top
        guard topInset > 0 else { return nil }

        let notchMinX = leftArea.maxX
        let notchMaxX = rightArea.minX
        guard notchMaxX > notchMinX else { return nil }

        let rect = CGRect(
            x: notchMinX,
            y: screen.frame.maxY - topInset,
            width: notchMaxX - notchMinX,
            height: topInset
        )
        return NotchGeometry(frame: rect, isRealNotch: true)
    }

    private static func fallback(on screen: NSScreen) -> NotchGeometry {
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let height = max(menuBarHeight, fallbackHeight)
        let rect = CGRect(
            x: screen.frame.midX - fallbackWidth / 2,
            y: screen.frame.maxY - height,
            width: fallbackWidth,
            height: height
        )
        return NotchGeometry(frame: rect, isRealNotch: false)
    }
}
