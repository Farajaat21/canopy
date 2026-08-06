import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var idleDelaySeconds: TimeInterval {
        didSet { UserDefaults.standard.set(idleDelaySeconds, forKey: Keys.idleDelay) }
    }

    @Published var launchAtLogin: Bool {
        didSet { LaunchAtLogin.setEnabled(launchAtLogin) }
    }

    private enum Keys {
        static let idleDelay = "idleDelaySeconds"
    }

    private init() {
        let stored = UserDefaults.standard.double(forKey: Keys.idleDelay)
        idleDelaySeconds = stored > 0 ? stored : IdleActivityMonitor.systemScreenSaverDelay()
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
