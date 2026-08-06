import Foundation

enum AppleScriptError: Error {
    case compileFailed
    case executionFailed(String)
}

/// Runs AppleScript synchronously against target apps (Music, Spotify) to read
/// now-playing state. NSAppleScript execution blocks on the Apple Events round trip,
/// so callers must invoke this off the main thread.
enum AppleScriptRunner {
    static func run(_ source: String) -> Result<NSAppleEventDescriptor, AppleScriptError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(.compileFailed)
        }
        var errorDict: NSDictionary?
        let result = script.executeAndReturnError(&errorDict)
        if let errorDict {
            let message = (errorDict[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript error"
            return .failure(.executionFailed(message))
        }
        return .success(result)
    }
}
