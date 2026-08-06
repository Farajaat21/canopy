import AppKit

struct ScriptedPlaybackState {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var position: TimeInterval
    var isPlaying: Bool
    var isShuffling: Bool
    var isRepeating: Bool
}

protocol NowPlayingSource: Sendable {
    var bundleIdentifier: String { get }

    /// Whether this source's shuffle/repeat state can actually be changed. Spotify's
    /// AppleScript dictionary reports `shuffling`/`repeating` but silently ignores
    /// attempts to set them (verified directly — no error, state just never changes),
    /// so its toggle buttons are shown disabled rather than pretending to work.
    var supportsShuffleAndRepeatControl: Bool { get }

    /// Reads current track/playback state. Returns nil if the app isn't running,
    /// isn't authorized (Automation permission not yet granted), or has nothing loaded.
    func fetchState() -> ScriptedPlaybackState?

    func fetchArtwork(completion: @escaping (NSImage?) -> Void)

    func playPause()
    func nextTrack()
    func previousTrack()
    func toggleShuffle()
    func toggleRepeat()
}

extension NowPlayingSource {
    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }
}
