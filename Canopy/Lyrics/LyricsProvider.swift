import Foundation
import os.log

/// Fetches synced lyrics from lrclib.net (free, keyless, community LRC lyrics),
/// with an in-memory + on-disk cache keyed by track/artist so repeat plays and
/// recently-played tracks work without refetching.
actor LyricsProvider {
    static let shared = LyricsProvider()

    private var memoryCache: [String: LyricsResult] = [:]
    private let cacheDirectory: URL
    private let log = Logger(subsystem: "dev.canopy.app", category: "Lyrics")

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        cacheDirectory = base.appendingPathComponent("dev.canopy.app/Lyrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func lyrics(forTitle title: String, artist: String, album: String, duration: TimeInterval) async -> LyricsResult? {
        guard !title.isEmpty else { return nil }
        let key = cacheKey(title: title, artist: artist)

        if let cached = memoryCache[key] {
            return cached
        }
        if let onDisk = readFromDisk(key: key) {
            memoryCache[key] = onDisk
            return onDisk
        }

        let fetched: LyricsResult?
        if let exact = await fetchExact(title: title, artist: artist, album: album, duration: duration) {
            fetched = exact
        } else {
            fetched = await fetchViaSearch(title: title, artist: artist)
        }
        guard let fetched else {
            log.debug("No lyrics found for \(title, privacy: .public) — \(artist, privacy: .public)")
            return nil
        }
        log.debug("Fetched \(fetched.lines.count) synced lines for \(title, privacy: .public) — \(artist, privacy: .public)")

        memoryCache[key] = fetched
        writeToDisk(key: key, result: fetched)
        return fetched
    }

    private func cacheKey(title: String, artist: String) -> String {
        let raw = "\(title)|\(artist)".lowercased()
        return raw.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
    }

    private func fetchExact(title: String, artist: String, album: String, duration: TimeInterval) async -> LyricsResult? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album),
            URLQueryItem(name: "duration", value: String(Int(duration.rounded()))),
        ]
        guard let url = components?.url else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let track = try? JSONDecoder().decode(LRCLibTrack.self, from: data) else { return nil }

        return makeResult(from: track)
    }

    private func fetchViaSearch(title: String, artist: String) async -> LyricsResult? {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        guard let url = components?.url else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let tracks = try? JSONDecoder().decode([LRCLibTrack].self, from: data),
              let best = tracks.first else { return nil }

        return makeResult(from: best)
    }

    private func makeResult(from track: LRCLibTrack) -> LyricsResult? {
        if let synced = track.syncedLyrics, !synced.isEmpty {
            let lines = LRCParser.parse(synced)
            if !lines.isEmpty {
                return LyricsResult(lines: lines, plainText: track.plainLyrics)
            }
        }
        if let plain = track.plainLyrics, !plain.isEmpty {
            return LyricsResult(lines: [], plainText: plain)
        }
        return nil
    }

    private func readFromDisk(key: String) -> LyricsResult? {
        let url = cacheDirectory.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode(CachedLyrics.self, from: data) else { return nil }
        return LyricsResult(
            lines: cached.lines.map { LyricLine(timestamp: $0.timestamp, text: $0.text) },
            plainText: cached.plainText
        )
    }

    private func writeToDisk(key: String, result: LyricsResult) {
        let url = cacheDirectory.appendingPathComponent("\(key).json")
        let cached = CachedLyrics(
            lines: result.lines.map { CachedLyricLine(timestamp: $0.timestamp, text: $0.text) },
            plainText: result.plainText
        )
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: url)
    }
}

private struct LRCLibTrack: Decodable {
    let plainLyrics: String?
    let syncedLyrics: String?
}

private struct CachedLyrics: Codable {
    let lines: [CachedLyricLine]
    let plainText: String?
}

private struct CachedLyricLine: Codable {
    let timestamp: TimeInterval
    let text: String
}
