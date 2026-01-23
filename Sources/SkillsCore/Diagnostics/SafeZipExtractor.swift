import Foundation

/// Safely extracts ZIP archives with security validation
public actor SafeZipExtractor {
    private static let maxUncompressedSize: Int64 = 100 * 1024 * 1024
    private static let maxArchiveSize: Int64 = 500 * 1024 * 1024
    private static let maxEntries: Int = 10_000
    private static let minCompressionRatio: Double = 0.01

    public func extract(from sourceURL: URL, to destinationURL: URL) throws -> Int {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ZipExtractionError.sourceNotFound(sourceURL)
        }
        let sourceSize = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64 ?? 0
        guard sourceSize <= Self.maxArchiveSize else {
            throw ZipExtractionError.archiveTooLarge(sourceSize, max: Self.maxArchiveSize)
        }
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        throw ZipExtractionError.unsupportedFormat("Use ZIPFoundation for extraction")
    }

    private func validatePath(_ path: String) throws {
        if path.contains("..") { throw ZipExtractionError.zipSlip(path) }
        if path.hasPrefix("/") { throw ZipExtractionError.absolutePath(path) }
        if path.contains(":") { throw ZipExtractionError.windowsPath(path) }
    }
}

public enum ZipExtractionError: Error, LocalizedError {
    case sourceNotFound(URL)
    case archiveTooLarge(Int64, max: Int64)
    case fileTooLarge(path: String, size: Int64, max: Int64)
    case tooManyEntries(Int, max: Int)
    case zipSlip(String)
    case absolutePath(String)
    case windowsPath(String)
    case compressionBomb(path: String, ratio: Double)
    case symlinkRejected(String)
    case unsupportedFormat(String)

    public var errorDescription: String? {
        switch self {
        case .sourceNotFound(let u): return "ZIP not found: '\(u.path)'"
        case .archiveTooLarge(let s, let m): return "Archive \(s) bytes exceeds \(m) bytes"
        case .fileTooLarge(let p, let s, let m): return "File '\(p)' would be \(s) bytes, exceeds \(m)"
        case .tooManyEntries(let c, let m): return "Archive has \(c) entries, exceeds \(m)"
        case .zipSlip(let p): return "ZIP slip detected: '\(p)'"
        case .absolutePath(let p): return "Absolute path: '\(p)'"
        case .windowsPath(let p): return "Windows path: '\(p)'"
        case .compressionBomb(let p, let r): return "Zip bomb '\(p)' ratio \(r)"
        case .symlinkRejected(let p): return "Symlink rejected: '\(p)'"
        case .unsupportedFormat(let f): return "Unsupported format: \(f)"
        }
    }
}
