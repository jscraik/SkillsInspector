import Foundation

/// Validates file system paths for security vulnerabilities
public actor PathSecurityValidator {
    private let restrictedPaths: Set<String> = [
        "/System", "/Library", "/usr", "/bin", "/sbin", "/etc", "/var/root"
    ]

    public func validatedDirectory(_ path: String) throws -> URL {
        try validateNoTraversal(path)
        try validateNotRestricted(path)
        let resolvedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: resolvedPath)
        _ = try validateURL(url)
        return url
    }

    public func validateURL(_ url: URL) throws -> URL {
        guard url.isFileURL else { throw PathSecurityValidationError.notAFileURL(url) }
        try validateNoTraversal(url.path)
        try validateNotRestricted(url.path)
        return url
    }

    public func validateWithinRoot(_ path: String, allowedRoot: URL) throws {
        let resolvedPath = (path as NSString).expandingTildeInPath
        let resolvedURL = URL(fileURLWithPath: resolvedPath)
        let resolvedRoot = allowedRoot.resolvingSymlinksInPath()
        let resolvedPathURL = resolvedURL.resolvingSymlinksInPath()
        guard resolvedPathURL.path.hasPrefix(resolvedRoot.path) else {
            throw PathSecurityValidationError.escapesAllowedRoot(path: resolvedPath, allowedRoot: resolvedRoot.path)
        }
    }

    private func validateNoTraversal(_ path: String) throws {
        if path.contains("..") { throw PathSecurityValidationError.parentDirectoryTraversal(path) }
        if path.contains("%2e%2e") || path.contains("%2E%2E") {
            throw PathSecurityValidationError.encodedTraversal(path)
        }
    }

    private func validateNotRestricted(_ path: String) throws {
        let expandedPath = (path as NSString).expandingTildeInPath
        for restricted in restrictedPaths {
            if expandedPath.hasPrefix(restricted) {
                throw PathSecurityValidationError.restrictedPath(path: expandedPath, reason: "System directory '\(restricted)' is protected")
            }
        }
    }
}

public enum PathSecurityValidationError: Error, LocalizedError {
    case parentDirectoryTraversal(String)
    case encodedTraversal(String)
    case restrictedPath(path: String, reason: String)
    case symlinkToRestricted(original: String, resolved: String)
    case escapesAllowedRoot(path: String, allowedRoot: String)
    case notAFileURL(URL)

    public var errorDescription: String? {
        switch self {
        case .parentDirectoryTraversal(let p): return "Path contains '..': '\(p)'"
        case .encodedTraversal(let p): return "Encoded traversal: '\(p)'"
        case .restrictedPath(let p, let r): return "Restricted path '\(p)': \(r)"
        case .symlinkToRestricted(let o, let r): return "Symlink '\(o)' to '\(r)'"
        case .escapesAllowedRoot(let p, let r): return "Escapes root '\(p)' from '\(r)'"
        case .notAFileURL(let u): return "Not a file URL: '\(u)'"
        }
    }
}
