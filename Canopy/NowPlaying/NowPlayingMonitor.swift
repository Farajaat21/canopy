import AppKit
import Combine
import os.log

@MainActor
final class NowPlayingMonitor: ObservableObject {
    static let shared = NowPlayingMonitor()

    @Published private(set) var info = NowPlayingInfo()

    private let sources: [NowPlayingSource] = [MusicAppSource(), SpotifyAppSource()]
    private let scriptingQueue = DispatchQueue(label: "dev.canopy.app.scripting")
    private let log = Logger(subsystem: "dev.canopy.app", category: "NowPlaying")

    private var pollTimer: Timer?
    private var isRefreshing = false
    private var lastArtworkSignature: String?
    private var activeSource: NowPlayingSource?

    private init() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        refresh()
    }

    deinit {
        pollTimer?.invalidate()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        scriptingQueue.async { [sources] in
            let now = Date()
            let state = sources.lazy.compactMap { source in
                source.fetchState().map { (source, $0) }
            }
            let playing = state.first { $0.1.isPlaying }
            let resolved = playing ?? state.first { _ in true }

            DispatchQueue.main.async { [weak self] in
                self?.apply(resolved, at: now)
            }
        }
    }

    func playPause() {
        scriptingQueue.async { [activeSource] in activeSource?.playPause() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    func nextTrack() {
        scriptingQueue.async { [activeSource] in activeSource?.nextTrack() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    func previousTrack() {
        scriptingQueue.async { [activeSource] in activeSource?.previousTrack() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    func toggleShuffle() {
        scriptingQueue.async { [activeSource] in activeSource?.toggleShuffle() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    func toggleRepeat() {
        scriptingQueue.async { [activeSource] in activeSource?.toggleRepeat() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    /// Brings the app currently providing now-playing info (Music or Spotify) to the
    /// foreground — tapping the artwork should jump you to the source, same as tapping
    /// a Live Activity on iOS.
    func activateSourceApp() {
        guard let bundleIdentifier = activeSource?.bundleIdentifier else { return }
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            app.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func apply(_ resolved: (NowPlayingSource, ScriptedPlaybackState)?, at timestamp: Date) {
        isRefreshing = false

        guard let (source, state) = resolved else {
            if info.hasTrack {
                log.debug("Now playing: nothing (no source has an active track)")
            }
            info = NowPlayingInfo()
            lastArtworkSignature = nil
            activeSource = nil
            return
        }
        activeSource = source

        var updated = NowPlayingInfo()
        updated.title = state.title
        updated.artist = state.artist
        updated.album = state.album
        updated.duration = state.duration
        updated.elapsedTimeAtTimestamp = state.position
        updated.timestamp = timestamp
        updated.playbackRate = state.isPlaying ? 1 : 0
        updated.isShuffling = state.isShuffling
        updated.isRepeating = state.isRepeating
        updated.supportsShuffleAndRepeatControl = source.supportsShuffleAndRepeatControl
        updated.artwork = info.trackSignature == updated.trackSignature ? info.artwork : nil

        let trackChanged = updated.trackSignature != info.trackSignature
        info = updated

        if trackChanged {
            log.debug("Now playing: \(updated.title, privacy: .public) — \(updated.artist, privacy: .public) via \(source.bundleIdentifier, privacy: .public)")
            lastArtworkSignature = updated.trackSignature
            source.fetchArtwork { [weak self] image in
                guard let self, self.lastArtworkSignature == updated.trackSignature else { return }
                self.info.artwork = image
            }
        }
    }
}
