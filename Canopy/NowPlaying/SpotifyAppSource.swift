import AppKit

/// Reads now-playing state from Spotify via AppleScript. Spotify doesn't expose raw
/// artwork data, only a remote artwork URL, so artwork is fetched over HTTP.
struct SpotifyAppSource: NowPlayingSource {
    let bundleIdentifier = "com.spotify.client"

    // Spotify reports `shuffling`/`repeating` but silently ignores attempts to set
    // them via AppleScript (verified directly: no error, state never actually changes).
    let supportsShuffleAndRepeatControl = false

    func fetchState() -> ScriptedPlaybackState? {
        guard isRunning else { return nil }

        let script = """
        tell application "Spotify"
            if player state is stopped then return ""
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackDuration to (duration of current track) / 1000
            set trackPosition to player position
            set trackState to (player state as string)
            set shuffleState to shuffling
            set repeatState to repeating
            return trackName & "␟" & trackArtist & "␟" & trackAlbum & "␟" & (trackDuration as string) & "␟" & (trackPosition as string) & "␟" & trackState & "␟" & (shuffleState as string) & "␟" & (repeatState as string)
        end tell
        """

        guard case .success(let descriptor) = AppleScriptRunner.run(script),
              let raw = descriptor.stringValue, !raw.isEmpty else { return nil }

        let parts = raw.components(separatedBy: "\u{241F}")
        guard parts.count == 8 else { return nil }

        return ScriptedPlaybackState(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            duration: Double(parts[3]) ?? 0,
            position: Double(parts[4]) ?? 0,
            isPlaying: parts[5] == "playing",
            isShuffling: parts[6] == "true",
            isRepeating: parts[7] == "true"
        )
    }

    func fetchArtwork(completion: @escaping (NSImage?) -> Void) {
        let script = """
        tell application "Spotify"
            return artwork url of current track
        end tell
        """
        guard case .success(let descriptor) = AppleScriptRunner.run(script),
              let urlString = descriptor.stringValue,
              let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let image = data.flatMap { NSImage(data: $0) }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }

    func playPause() {
        _ = AppleScriptRunner.run(#"tell application "Spotify" to playpause"#)
    }

    func nextTrack() {
        _ = AppleScriptRunner.run(#"tell application "Spotify" to next track"#)
    }

    func previousTrack() {
        _ = AppleScriptRunner.run(#"tell application "Spotify" to previous track"#)
    }

    func toggleShuffle() {
        // No-op: Spotify's AppleScript bridge doesn't actually let this be set.
    }

    func toggleRepeat() {
        // No-op: same limitation as shuffle.
    }
}
