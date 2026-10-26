import Foundation

/// Where transcripts are saved. A folder the user picked is remembered with a security-scoped
/// bookmark; until then `~/Documents/Transcripts` is used (allowed by a sandbox entitlement).
enum OutputFolder {
    /// The real home folder. Inside the App Sandbox `homeDirectoryForCurrentUser` points to the container.
    static var realHomeDirectory: URL {
        if let passwd = getpwuid(getuid()), let dir = passwd.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var defaultURL: URL {
        realHomeDirectory.appendingPathComponent("Documents/Transcripts", isDirectory: true)
    }

    static func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// The saved folder, or the default one if there is no usable bookmark.
    static func resolve(bookmark: Data?) -> URL {
        guard let bookmark else { return defaultURL }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return defaultURL }
        if isStale, let fresh = try? makeBookmark(for: url) {
            UserDefaults.standard.set(fresh, forKey: SettingsKey.outputFolderBookmark)
        }
        return url
    }

    /// Runs `body` with write access to the output folder.
    static func withAccess<T>(bookmark: Data?, _ body: (URL) throws -> T) throws -> T {
        let url = resolve(bookmark: bookmark)
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try body(url)
    }

    /// Path for display, with the home folder shortened to `~`.
    static func displayPath(bookmark: Data?) -> String {
        let path = resolve(bookmark: bookmark).path
        let home = realHomeDirectory.path
        guard path == home || path.hasPrefix(home + "/") else { return path }
        return "~" + String(path.dropFirst(home.count))
    }
}
