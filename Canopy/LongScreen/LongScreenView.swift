import AppKit
import SwiftUI
import os.log

private let longScreenLog = Logger(subsystem: "dev.canopy.app", category: "LongScreenUI")

struct LongScreenView: View {
    @ObservedObject private var nowPlaying = NowPlayingMonitor.shared
    @State private var lyricsResult: LyricsResult?
    @State private var isLoadingLyrics = false
    @State private var showLyrics = true
    @State private var outputDeviceName = ""
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var activityMonitor: Any?

    var onClose: () -> Void = {}

    private let autoHideDelay: Duration = .seconds(4)

    /// Shared horizontal margin used by both the artwork/lyrics row and the bottom
    /// bar below it, so the progress bar's width defines the content boundary that
    /// everything else lines up against — not a narrower, separately-centered block.
    private let contentMargin: CGFloat = 80

    var body: some View {
        ZStack {
            backgroundArtwork

            if nowPlaying.info.hasTrack {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    mainContent
                    Spacer(minLength: 24)
                    bottomBar
                }
                .padding(.horizontal, contentMargin)
                .padding(.bottom, 44)
            } else {
                nothingPlayingState
            }

            VStack {
                HStack {
                    closeButton
                    Spacer()
                }
                Spacer()
            }
            .padding(24)
        }
        .animation(.easeInOut(duration: 0.3), value: controlsVisible)
        .background(Color.black)
        .ignoresSafeArea()
        .task(id: nowPlaying.info.trackSignature) {
            await loadLyrics()
        }
        .task {
            outputDeviceName = AudioOutputMonitor.currentOutputDeviceName() ?? "This Mac"
        }
        .onAppear {
            registerActivityMonitor()
            scheduleAutoHide()
        }
        .onDisappear {
            if let activityMonitor {
                NSEvent.removeMonitor(activityMonitor)
            }
            hideTask?.cancel()
        }
    }

    private func registerActivityMonitor() {
        activityMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .scrollWheel, .leftMouseDown, .rightMouseDown]
        ) { event in
            revealControls()
            return event
        }
        longScreenLog.debug("Activity monitor registered")
    }

    private func revealControls() {
        controlsVisible = true
        scheduleAutoHide()
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        longScreenLog.debug("Scheduling auto-hide in \(autoHideDelay.components.seconds)s")
        hideTask = Task {
            try? await Task.sleep(for: autoHideDelay)
            guard !Task.isCancelled else {
                longScreenLog.debug("Auto-hide task cancelled")
                return
            }
            longScreenLog.debug("Auto-hide firing now")
            controlsVisible = false
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var nothingPlayingState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.3))
            Text("Nothing Playing")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text("Press any key to dismiss")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Main content (artwork + lyrics)

    private var mainContent: some View {
        HStack(alignment: .center, spacing: 64) {
            artworkView
                .frame(width: showLyrics ? 380 : 460, height: showLyrics ? 380 : 460)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 36, y: 14)

            if showLyrics {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    lyricsContent(at: context.date)
                }
                .frame(maxWidth: .infinity, maxHeight: 520, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: showLyrics ? .leading : .center)
    }

    @ViewBuilder
    private func lyricsContent(at date: Date) -> some View {
        if let lines = lyricsResult?.lines, !lines.isEmpty {
            LyricsPanel(lines: lines, currentTime: nowPlaying.info.currentElapsedTime(now: date))
        } else if let plain = lyricsResult?.plainText, !plain.isEmpty {
            ScrollView {
                Text(plain)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if isLoadingLyrics {
            ProgressView().tint(.white)
        } else {
            Text("No lyrics found")
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = nowPlaying.info.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                )
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(nowPlaying.info.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(nowPlaying.info.artist)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                progressRow(at: context.date)
            }

            transportControls
                .frame(maxWidth: .infinity)
                .opacity(controlsVisible ? 1 : 0)
                .offset(y: controlsVisible ? 0 : 8)

            HStack {
                outputDeviceIndicator
                Spacer()
                lyricsToggleButton
            }
        }
    }

    private func progressRow(at date: Date) -> some View {
        let elapsed = nowPlaying.info.currentElapsedTime(now: date)
        let duration = max(nowPlaying.info.duration, 1)

        return VStack(spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.22))
                    Capsule().fill(Color.white)
                        .frame(width: geo.size.width * min(1, max(0, elapsed / duration)))
                }
            }
            .frame(height: 6)

            HStack {
                Text(formatted(elapsed))
                Spacer()
                Text("-" + formatted(max(0, nowPlaying.info.duration - elapsed)))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var transportControls: some View {
        HStack(spacing: 40) {
            shuffleButton
            Button {
                NowPlayingMonitor.shared.previousTrack()
            } label: {
                Image(systemName: "backward.fill").font(.system(size: 18))
            }

            Button {
                NowPlayingMonitor.shared.playPause()
            } label: {
                Image(systemName: nowPlaying.info.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.15), in: Circle())
            }

            Button {
                NowPlayingMonitor.shared.nextTrack()
            } label: {
                Image(systemName: "forward.fill").font(.system(size: 18))
            }
            repeatButton
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private var shuffleButton: some View {
        let supported = nowPlaying.info.supportsShuffleAndRepeatControl
        return Button {
            NowPlayingMonitor.shared.toggleShuffle()
        } label: {
            Image(systemName: "shuffle")
                .font(.system(size: 15))
                .foregroundStyle(nowPlaying.info.isShuffling ? .white : .white.opacity(0.5))
        }
        .buttonStyle(.plain)
        .disabled(!supported)
        .opacity(supported ? 1 : 0.35)
        .help(supported ? "Shuffle" : "This app doesn't support remote shuffle control")
    }

    private var repeatButton: some View {
        let supported = nowPlaying.info.supportsShuffleAndRepeatControl
        return Button {
            NowPlayingMonitor.shared.toggleRepeat()
        } label: {
            Image(systemName: "repeat")
                .font(.system(size: 15))
                .foregroundStyle(nowPlaying.info.isRepeating ? .white : .white.opacity(0.5))
        }
        .buttonStyle(.plain)
        .disabled(!supported)
        .opacity(supported ? 1 : 0.35)
        .help(supported ? "Repeat" : "This app doesn't support remote repeat control")
    }

    private var outputDeviceIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "airplayaudio")
                .font(.system(size: 13))
            Text(outputDeviceName)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.55))
    }

    private var lyricsToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showLyrics.toggle()
            }
        } label: {
            Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(showLyrics ? 0.9 : 0.5))
        }
        .buttonStyle(.plain)
        .help(showLyrics ? "Hide Lyrics" : "Show Lyrics")
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Background

    /// The background *is* the album art itself — heavily blurred and darkened —
    /// same technique Apple Music and Spotify actually use, rather than a computed
    /// color gradient standing in for it.
    @ViewBuilder
    private var backgroundArtwork: some View {
        if let artwork = nowPlaying.info.artwork {
            GeometryReader { geo in
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .blur(radius: 100)
                    .overlay(Color.black.opacity(0.45))
                    .saturation(1.3)
            }
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.6), value: nowPlaying.info.trackSignature)
        } else {
            LinearGradient(colors: [Color(white: 0.1), Color(white: 0.02)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }

    // MARK: - Data loading

    private func loadLyrics() async {
        guard nowPlaying.info.hasTrack else {
            lyricsResult = nil
            return
        }
        lyricsResult = nil
        isLoadingLyrics = true
        let result = await LyricsProvider.shared.lyrics(
            forTitle: nowPlaying.info.title,
            artist: nowPlaying.info.artist,
            album: nowPlaying.info.album,
            duration: nowPlaying.info.duration
        )
        isLoadingLyrics = false
        lyricsResult = result
    }
}

private struct LyricsPanel: View {
    let lines: [LyricLine]
    let currentTime: TimeInterval

    private var activeIndex: Int? {
        var result: Int?
        for (index, line) in lines.enumerated() {
            if line.timestamp <= currentTime {
                result = index
            } else {
                break
            }
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text.isEmpty ? "♪" : line.text)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(index == activeIndex ? .white : .white.opacity(0.32))
                            .multilineTextAlignment(.leading)
                            .id(line.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.25), value: activeIndex)
                .padding(.vertical, 220)
            }
            .onChange(of: activeIndex) { _, newValue in
                guard let newValue, lines.indices.contains(newValue) else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(lines[newValue].id, anchor: UnitPoint(x: 0.5, y: 0.4))
                }
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.88),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
