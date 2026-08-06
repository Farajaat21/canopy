import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let timestamp: TimeInterval
    let text: String
}

struct LyricsResult {
    let lines: [LyricLine]
    let plainText: String?
}
