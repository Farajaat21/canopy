import AppKit

/// Reads now-playing state from Apple's Music app via AppleScript.
struct MusicAppSource: NowPlayingSource {
    let bundleIdentifier = "com.apple.Music"
    let supportsShuffleAndRepeatControl = true

    func fetchState() -> ScriptedPlaybackState? {
        guard isRunning else { return nil }

        let script = """
        tell application "Music"
            if player state is stopped then return ""
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackDuration to duration of current track
            set trackPosition to player position
            set trackState to (player state as string)
            set shuffleState to shuffle enabled
            set repeatState to (song repeat is not off)
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
        tell application "Music"
            if (count of artworks of current track) is 0 then return
            return raw data of artwork 1 of current track
        end tell
        """
        guard case .success(let descriptor) = AppleScriptRunner.run(script) else {
            completion(nil)
            return
        }
        let data = descriptor.data
        completion(data.isEmpty ? nil : NSImage(data: data))
    }

    func playPause() {
        _ = AppleScriptRunner.run(#"tell application "Music" to playpause"#)
    }

    func nextTrack() {
        _ = AppleScriptRunner.run(#"tell application "Music" to next track"#)
    }

    func previousTrack() {
        _ = AppleScriptRunner.run(#"tell application "Music" to previous track"#)
    }

    func toggleShuffle() {
        _ = AppleScriptRunner.run(#"tell application "Music" to set shuffle enabled to not shuffle enabled"#)
    }

    func toggleRepeat() {
        _ = AppleScriptRunner.run("""
        tell application "Music"
            if song repeat is off then
                set song repeat to all
            else
                set song repeat to off
            end if
        end tell
        """)
    }
}
