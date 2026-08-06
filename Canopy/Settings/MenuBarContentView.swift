import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject private var nowPlaying = NowPlayingMonitor.shared

    var body: some View {
        Text(nowPlaying.info.hasTrack ? "\(nowPlaying.info.title) — \(nowPlaying.info.artist)" : "Nothing playing")

        Divider()

        Button("Open Long Screen") {
            AppCoordinator.shared.openLongScreenManually()
        }
        .keyboardShortcut("l", modifiers: [.command, .option])

        Button("Preferences…") {
            AppCoordinator.shared.openPreferences()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Canopy") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
