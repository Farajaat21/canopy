# Canopy

A macOS menu-bar utility that turns your MacBook's notch into a Dynamic
Island-style now-playing pill, plus a fullscreen "long screen" lyrics view
that appears when your Mac goes idle.

## Features

- **Notch pill** — compact indicator when music is playing, expands on
  hover/click into artwork, title/artist, progress, and mini playback
  controls (prev/play-pause/next, shuffle/repeat). Tap the artwork to jump
  to the source app.
- **Auto-preview** — briefly expands on its own when a new track starts,
  like a Live Activity announcing itself.
- **Long screen** — a fullscreen, Apple-Music-style view with a background
  blurred from the album art itself, big synced scrolling lyrics, transport
  controls, and the connected audio output device. Appears automatically
  after the Mac has been idle for a while with music playing, or open it
  manually with a hotkey.
- **Now-playing source**: Music.app and Spotify, read via AppleScript (see
  [Limitations](#limitations) for why, not the private MediaRemote API).
- **Lyrics**: synced (LRC) lyrics from [lrclib.net](https://lrclib.net),
  free and keyless.

## Requirements

- macOS 14 (Sonoma) or later
- A notch (MacBook Pro 14"/16", 2021+) for the full effect — falls back to
  anchoring the pill to the top-center of the menu bar on other Macs.
- [Xcode](https://developer.apple.com/xcode/) and
  [XcodeGen](https://github.com/yonaskolb/XcodeGen) to build

## Building

```sh
brew install xcodegen   # if you don't have it
xcodegen generate
xcodebuild -project Canopy.xcodeproj -scheme Canopy -configuration Debug build
```

Or open `Canopy.xcodeproj` in Xcode and run.

The app is unsandboxed and signed ad hoc (`CODE_SIGN_IDENTITY = "-"`) for
local development. For real distribution, set `DEVELOPMENT_TEAM` and a
Developer ID Application identity in `project.yml`, then notarize.

## Permissions

On first launch, macOS will ask you to grant Canopy Automation permission
to control Music and/or Spotify — that's how it reads now-playing info and
sends playback commands. Grant both if you use both. You can manage this
later in **System Settings → Privacy & Security → Automation**.

## Limitations

- **No system-wide now-playing (e.g. Safari/Chrome tabs)** — the private
  `MediaRemote` framework that Control Center uses for this requires an
  Apple-granted entitlement (`com.apple.mediaremote.readNowPlayingInfo`)
  that isn't available to third-party apps without approval. Canopy falls
  back to AppleScript against Music.app and Spotify specifically.
- **Spotify shuffle/repeat can't be toggled remotely** — Spotify's
  AppleScript dictionary reports `shuffling`/`repeating` state but silently
  ignores attempts to set them (verified directly: no error, state just
  never changes). Those buttons are shown disabled for Spotify; Music.app's
  work normally.
- **No vocal removal** — the "Sing"-style vocal toggle seen in Apple Music
  requires real-time DSP on the actual audio stream, which is a different
  category of engineering than AppleScript/MediaRemote can provide.
