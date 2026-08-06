import AppKit
import Combine
import SwiftUI
import os.log

@MainActor
final class NotchWindowController {
    static let shared = NotchWindowController()

    private let log = Logger(subsystem: "dev.canopy.app", category: "Notch")

    /// Set by whatever owns the long-screen feature so the notch's expand button can trigger it.
    var requestLongScreen: (() -> Void)?

    private var panel: NotchPanel?
    private var geometry: NotchGeometry?
    private let viewModel = NotchViewModel()
    private var collapseWorkItem: DispatchWorkItem?
    private var autoPreviewWorkItem: DispatchWorkItem?
    private var isUserHovering = false
    private var lastAnnouncedTrackSignature: String?
    private var cancellables = Set<AnyCancellable>()

    private let expandedSize = CGSize(width: 380, height: 138)
    private let collapseDelay: TimeInterval = 0.5
    private let autoPreviewDuration: TimeInterval = 3.0

    /// Extra width beyond the true notch bounds, so peeking artwork/indicators have
    /// room to sit either side of the physical camera housing — the standard trick
    /// notch-clone apps use, since we're just painting extra black pixels around it.
    private let collapsedExtraWidth: CGFloat = 64

    private func collapsedFrame(for geometry: NotchGeometry) -> CGRect {
        geometry.frame.insetBy(dx: -collapsedExtraWidth / 2, dy: 0)
    }

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func activate() {
        rebuildPanel()

        NowPlayingMonitor.shared.$info
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.handleNowPlayingChange(info)
            }
            .store(in: &cancellables)
    }

    /// The signature "song arrives in the island" moment: briefly auto-expand when a
    /// new track starts playing, then settle back to the compact pill — like a Dynamic
    /// Island Live Activity announcing itself, rather than only expanding on hover.
    private func handleNowPlayingChange(_ info: NowPlayingInfo) {
        guard info.hasTrack else {
            lastAnnouncedTrackSignature = nil
            return
        }
        guard info.isPlaying, info.trackSignature != lastAnnouncedTrackSignature else { return }
        lastAnnouncedTrackSignature = info.trackSignature
        log.debug("New track started, previewing in island: \(info.title, privacy: .public)")
        showAutoPreview()
    }

    private func showAutoPreview() {
        guard !viewModel.isExpanded else { return }
        collapseWorkItem?.cancel()
        setExpanded(true)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isUserHovering else { return }
            self.setExpanded(false)
        }
        autoPreviewWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoPreviewDuration, execute: workItem)
    }

    @objc private func screenParametersChanged() {
        rebuildPanel()
    }

    private func rebuildPanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            panel?.orderOut(nil)
            return
        }

        let newGeometry = NotchGeometry.detect(for: screen)
        geometry = newGeometry
        viewModel.isExpanded = false

        log.debug("Notch geometry: frame=\(NSStringFromRect(newGeometry.frame), privacy: .public) isRealNotch=\(newGeometry.isRealNotch) screenFrame=\(NSStringFromRect(screen.frame), privacy: .public)")

        let content = NotchPillView(
            viewModel: viewModel,
            onHoverChanged: { [weak self] hovering in
                self?.handleHover(hovering)
            },
            onTapExpanded: { [weak self] in
                self?.requestLongScreen?()
            }
        )
        let hostingView = NSHostingView(rootView: content)

        let collapsed = collapsedFrame(for: newGeometry)

        if let panel {
            panel.contentView = hostingView
            panel.setFrame(collapsed, display: true)
        } else {
            let newPanel = NotchPanel(contentRect: collapsed)
            newPanel.contentView = hostingView
            newPanel.orderFrontRegardless()
            panel = newPanel
        }
    }

    private func handleHover(_ hovering: Bool) {
        isUserHovering = hovering
        collapseWorkItem?.cancel()

        if hovering {
            autoPreviewWorkItem?.cancel()
            setExpanded(true)
        } else {
            let workItem = DispatchWorkItem { [weak self] in
                self?.setExpanded(false)
            }
            collapseWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + collapseDelay, execute: workItem)
        }
    }

    private func setExpanded(_ expanded: Bool) {
        guard let geometry, let panel else { return }
        viewModel.isExpanded = expanded

        let targetFrame: CGRect
        let timingFunction: CAMediaTimingFunction
        let duration: TimeInterval

        if expanded {
            targetFrame = CGRect(
                x: geometry.frame.midX - expandedSize.width / 2,
                y: geometry.frame.maxY - expandedSize.height,
                width: expandedSize.width,
                height: expandedSize.height
            )
            // Slight overshoot to approximate a spring/bounce feel.
            timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
            duration = 0.42
        } else {
            targetFrame = collapsedFrame(for: geometry)
            timingFunction = CAMediaTimingFunction(controlPoints: 0.32, 0, 0.67, 0)
            duration = 0.28
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timingFunction
            panel.animator().setFrame(targetFrame, display: true)
        }
    }
}
