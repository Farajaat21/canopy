import AppKit
import Combine
import os.log

@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    private let idleMonitor = IdleActivityMonitor()
    private let hotKey = GlobalHotKeyMonitor()
    private let log = Logger(subsystem: "dev.canopy.app", category: "Coordinator")
    private var cancellables = Set<AnyCancellable>()

    private var hasStarted = false

    private init() {}

    func start() {
        guard !hasStarted else {
            log.error("start() called again, ignoring — was already started")
            return
        }
        hasStarted = true

        NotchWindowController.shared.activate()
        NotchWindowController.shared.requestLongScreen = {
            LongScreenWindowController.shared.show(reason: "notch-button")
        }

        idleMonitor.onIdleStart = {
            guard NowPlayingMonitor.shared.info.isPlaying else { return }
            LongScreenWindowController.shared.show(reason: "idle")
        }
        idleMonitor.onIdleEnd = {
            LongScreenWindowController.shared.hide(reason: "idle-end")
        }
        idleMonitor.idleThreshold = AppSettings.shared.idleDelaySeconds
        idleMonitor.start()
        log.debug("Idle threshold set to \(self.idleMonitor.idleThreshold, format: .fixed(precision: 0))s")

        AppSettings.shared.$idleDelaySeconds
            .sink { [weak self] newValue in
                self?.idleMonitor.idleThreshold = newValue
            }
            .store(in: &cancellables)

        hotKey.action = {
            LongScreenWindowController.shared.toggle(reason: "hotkey")
        }
        hotKey.register()
    }

    func openLongScreenManually() {
        LongScreenWindowController.shared.toggle(reason: "menu")
    }

    func openPreferences() {
        PreferencesWindowController.shared.show()
    }
}
