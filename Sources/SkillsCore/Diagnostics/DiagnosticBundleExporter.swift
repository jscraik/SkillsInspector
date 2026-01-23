import Foundation
import ZIPFoundation

/// Exports diagnostic bundles to ZIP archives containing JSON manifest and supporting files.
///
/// The exporter creates a ZIP file with the following structure:
/// ```
/// diagnostics-YYYYMMDD-HHMMSS.zip
/// ├── manifest.json       # Full DiagnosticBundle (redacted)
/// ├── findings.json       # Recent validation findings (redacted)
/// ├── events.json         # Recent ledger events (redacted)
/// └── system.json         # System information snapshot
/// ```
public struct DiagnosticBundleExporter: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Constants

    /// Maximum allowed bundle size in bytes (5 MB)
    public static let maxBundleSize: Int64 = 5 * 1024 * 1024

    /// Maximum allowed number of files in bundle
    public static let maxFileCount: Int = 1000

    // MARK: - Errors

    public enum ExportError: LocalizedError {
        case zipCreationFailed(String)
        case fileWriteFailed(String)
        case invalidOutputPath(URL)
        case bundleTooLarge(Int64, Int64)
        case tooManyFiles(Int, Int)

        public var errorDescription: String? {
            switch self {
            case .zipCreationFailed(let reason):
                return "Failed to create ZIP archive: \(reason)"
            case .fileWriteFailed(let reason):
                return "Failed to write bundle file: \(reason)"
            case .invalidOutputPath(let url):
                return "Invalid output path: \(url.path)"
            case .bundleTooLarge(let actualSize, let maxSize):
                let sizeMB = Double(actualSize) / 1024 / 1024
                let maxMB = Double(maxSize) / 1024 / 1024
                return "Bundle too large: \(String(format: "%.2f", sizeMB)) MB exceeds maximum of \(String(format: "%.2f", maxMB)) MB"
            case .tooManyFiles(let actualCount, let maxCount):
                return "Too many files: \(actualCount) files exceeds maximum of \(maxCount)"
            }
        }
    }

    // MARK: - Export

    /// Exports a diagnostic bundle to a ZIP archive at the specified path.
    ///
    /// - Parameters:
    ///   - bundle: The diagnostic bundle to export
    ///   - outputURL: The destination URL for the ZIP file (should end in .zip)
    /// - Returns: The URL of the created ZIP archive
    /// - Throws: `ExportError` if ZIP creation or file writing fails
    public func export(bundle: DiagnosticBundle, to outputURL: URL) throws -> URL {
        // Validate output path
        guard outputURL.pathExtension == "zip" else {
            throw ExportError.invalidOutputPath(outputURL)
        }

        // Create parent directory if needed
        let parentDir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Encode bundle components to JSON with consistent formatting
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let manifestData = try bundle.toJSON()
        let findingsData = try encoder.encode(bundle.recentFindings)
        let eventsData = try encoder.encode(bundle.ledgerEvents)
        let systemData = try encoder.encode(bundle.systemInfo)

        // Calculate total size
        let totalSize = Int64(manifestData.count + findingsData.count + eventsData.count + systemData.count)

        // Validate size limit
        guard totalSize <= Self.maxBundleSize else {
            throw ExportError.bundleTooLarge(totalSize, Self.maxBundleSize)
        }

        // Validate file count (4 fixed files)
        let fileCount = 4
        guard fileCount <= Self.maxFileCount else {
            throw ExportError.tooManyFiles(fileCount, Self.maxFileCount)
        }

        // Open archive for writing (creates the file if it doesn't exist)
        let archive: Archive
        do {
            archive = try Archive(url: outputURL, accessMode: .create)
        } catch {
            throw ExportError.zipCreationFailed("Failed to open archive at \(outputURL.path): \(error.localizedDescription)")
        }

        // Add manifest.json (full bundle)
        try addEntry(to: archive, path: "manifest.json", data: manifestData)

        // Add findings.json (recent findings only)
        try addEntry(to: archive, path: "findings.json", data: findingsData)

        // Add events.json (recent events only)
        try addEntry(to: archive, path: "events.json", data: eventsData)

        // Add system.json (system info for quick reference)
        try addEntry(to: archive, path: "system.json", data: systemData)

        return outputURL
    }

    /// Generates a default output URL with timestamp in the user's Desktop directory.
    ///
    /// - Returns: A URL like `~/Desktop/diagnostics-20260120-152345.zip`
    public func defaultOutputURL() -> URL {
        let date = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        let dateString = String(format: "%04d%02d%02d",
                                components.year ?? 0,
                                components.month ?? 0,
                                components.day ?? 0)
        let timeString = String(format: "%02d%02d%02d",
                                components.hour ?? 0,
                                components.minute ?? 0,
                                components.second ?? 0)

        let filename = "diagnostics-\(dateString)-\(timeString).zip"

        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            return desktopURL.appendingPathComponent(filename)
        }

        // Fallback to temp directory if Desktop unavailable
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    // MARK: - Private Helper

    /// Adds a JSON entry to the ZIP archive with proper compression.
    ///
    /// - Parameters:
    ///   - archive: The archive to add the entry to
    ///   - path: The entry path within the ZIP
    ///   - data: The data to compress and add
    /// - Throws: ZIPFoundation errors if compression fails
    private func addEntry(to archive: Archive, path: String, data: Data) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate
        ) { position, chunkSize in
            let endPosition = min(position + Int64(chunkSize), Int64(data.count))
            return data.subdata(in: Int(position)..<Int(endPosition))
        }
    }
}
