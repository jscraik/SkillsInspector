import Foundation

/// Collects system information for diagnostic bundles.
/// Uses ProcessInfo and sysctl to gather macOS system data.
public enum SystemInfoCollector: Sendable {

    /// Collect current system information.
    /// - Returns: SystemInfo with macOS version, architecture, hostname (redacted), disk space, and memory.
    public static func collect() -> SystemInfo {
        let processInfo = ProcessInfo.processInfo

        let macOSVersion = processInfo.operatingSystemVersionString
        let architecture = getArchitecture()
        let hostName = TelemetryRedactor.redactHostName(processInfo.hostName)
        let availableDiskSpace = getAvailableDiskSpace()
        let totalMemory = getTotalMemory()

        return SystemInfo(
            macOSVersion: macOSVersion,
            architecture: architecture,
            hostName: hostName,
            availableDiskSpace: availableDiskSpace,
            totalMemory: totalMemory
        )
    }

    // MARK: - Private Helpers

    /// Get system architecture using sysctl hw.machine
    private static func getArchitecture() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)

        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)

        // Truncate at null terminator, then decode as UTF-8.
        let endIndex = machine.firstIndex(of: 0) ?? machine.count
        let bytes = machine.prefix(endIndex).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Get available disk space on the boot volume.
    private static func getAvailableDiskSpace() -> Int64 {
        do {
            let url = FileManager.default.homeDirectoryForCurrentUser.deletingLastPathComponent()
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return Int64(capacity)
            }
        } catch {
            // Fall back to zero if unable to retrieve
        }
        return 0
    }

    /// Get total physical memory using sysctl hw.memsize.
    private static func getTotalMemory() -> Int64 {
        var size: UInt64 = 0
        var sizeofSize = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &sizeofSize, nil, 0)
        return Int64(bitPattern: size)
    }
}

// MARK: - Type Alias

/// System information model for diagnostic bundles.
public typealias SystemInfo = DiagnosticBundle.SystemInfo
