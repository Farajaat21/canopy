import SwiftUI

struct NotchPillView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject private var nowPlaying = NowPlayingMonitor.shared
    var onHoverChanged: (Bool) -> Void
    var onTapExpanded: () -> Void

    var body: some View {
        Group {
            if viewModel.isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .onHover { hovering in
            onHoverChanged(hovering)
        }
    }

    private var collapsedContent: some View {
        HStack {
            if nowPlaying.info.hasTrack {
                collapsedArtwork
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NowPlayingMonitor.shared.activateSourceApp()
                    }
            }

            Spacer(minLength: 0)

            if nowPlaying.info.isPlaying {
                PlayingIndicator()
                    .frame(width: 14, height: 12)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(notchShape(radius: 10))
    }

    @ViewBuilder
    private var collapsedArtwork: some View {
        if let artwork = nowPlaying.info.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(0.15))
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                artworkView
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NowPlayingMonitor.shared.activateSourceApp()
                    }
                    .help("Open source app")

                VStack(alignment: .leading, spacing: 5) {
                    Text(nowPlaying.info.hasTrack ? nowPlaying.info.title : "Nothing Playing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(nowPlaying.info.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        ProgressBar(progress: progressFraction(at: context.date))
                            .frame(height: 3)
                    }
                }

                Spacer(minLength: 0)

                Button(action: onTapExpanded) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            miniTransportControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.black)
        .clipShape(notchShape(radius: 24))
    }

    private var miniTransportControls: some View {
        HStack(spacing: 28) {
            Button {
                NowPlayingMonitor.shared.previousTrack()
            } label: {
                Image(systemName: "backward.fill").font(.system(size: 13))
            }

            Button {
                NowPlayingMonitor.shared.playPause()
            } label: {
                Image(systemName: nowPlaying.info.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
            }

            Button {
                NowPlayingMonitor.shared.nextTrack()
            } label: {
                Image(systemName: "forward.fill").font(.system(size: 13))
            }
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = nowPlaying.info.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.4))
                )
        }
    }

    private func progressFraction(at date: Date) -> Double {
        guard nowPlaying.info.duration > 0 else { return 0 }
        return nowPlaying.info.currentElapsedTime(now: date) / nowPlaying.info.duration
    }

    private func notchShape(radius: CGFloat) -> some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }
}

private struct PlayingIndicator: View {
    @State private var animate = false
    private let barHeights: [CGFloat] = [10, 6, 12]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barHeights.count, id: \.self) { index in
                Capsule()
                    .fill(Color.green)
                    .frame(width: 2, height: animate ? barHeights[index] : 3)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.12),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

private struct ProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule().fill(Color.white)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
    }
}
