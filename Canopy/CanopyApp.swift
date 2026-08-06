import SwiftUI

@main
struct CanopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Canopy", systemImage: "sparkles") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.menu)
    }
}
