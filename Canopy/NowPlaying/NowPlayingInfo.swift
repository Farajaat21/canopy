import AppKit

struct NowPlayingInfo {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var artwork: NSImage?
    var duration: TimeInterval = 0
    var elapsedTimeAtTimestamp: TimeInterval = 0
    var timestamp: Date = .distantPast
    var playbackRate: Double = 0
    var isShuffling: Bool = false
    var isRepeating: Bool = false
    var supportsShuffleAndRepeatControl: Bool = false

    var isPlaying: Bool { playbackRate > 0 }
    var hasTrack: Bool { !title.isEmpty }
    var trackSignature: String { "\(title)|\(artist)|\(album)" }

    func currentElapsedTime(now: Date = Date()) -> TimeInterval {
        guard isPlaying else { return elapsedTimeAtTimestamp }
        let delta = now.timeIntervalSince(timestamp) * playbackRate
        return min(max(0, elapsedTimeAtTimestamp + delta), duration)
    }
}

extension NowPlayingInfo: Equatable {
    static func == (lhs: NowPlayingInfo, rhs: NowPlayingInfo) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        lhs.duration == rhs.duration &&
        lhs.elapsedTimeAtTimestamp == rhs.elapsedTimeAtTimestamp &&
        lhs.timestamp == rhs.timestamp &&
        lhs.playbackRate == rhs.playbackRate
    }
}
