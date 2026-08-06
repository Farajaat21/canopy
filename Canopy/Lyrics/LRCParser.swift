import Foundation

/// Parses standard LRC synced-lyrics text ("[mm:ss.xx] line") into timed lines.
/// Non-timestamp metadata tags (e.g. "[ar:Artist]") are silently skipped since their
/// tag content doesn't parse as a "minutes:seconds" pair.
enum LRCParser {
    static func parse(_ raw: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            var remaining = Substring(rawLine)
            guard remaining.hasPrefix("[") else { continue }

            var timestamps: [TimeInterval] = []
            while remaining.hasPrefix("["), let closeIndex = remaining.firstIndex(of: "]") {
                let tag = remaining[remaining.index(after: remaining.startIndex)..<closeIndex]
                if let time = parseTimeTag(String(tag)) {
                    timestamps.append(time)
                }
                remaining = remaining[remaining.index(after: closeIndex)...]
            }

            guard !timestamps.isEmpty else { continue }
            let text = remaining.trimmingCharacters(in: .whitespaces)
            for timestamp in timestamps {
                lines.append(LyricLine(timestamp: timestamp, text: text))
            }
        }

        return lines.sorted { $0.timestamp < $1.timestamp }
    }

    private static func parseTimeTag(_ tag: String) -> TimeInterval? {
        let parts = tag.split(separator: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1]) else { return nil }
        return minutes * 60 + seconds
    }
}
