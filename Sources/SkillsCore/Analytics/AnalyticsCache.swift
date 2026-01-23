import Foundation

/// Cache for analytics query results with TTL support
public actor AnalyticsCache {
    private let ledger: SkillLedger

    public init(ledger: SkillLedger) {
        self.ledger = ledger
    }

    /// Gets a cached value by key
    /// - Parameter key: Cache key
    /// - Returns: Cached value if exists and not expired, nil otherwise
    public func get(key: String) async throws -> String? {
        return try await ledger.analyticsCacheGet(key: key)
    }

    /// Sets a cached value with TTL
    /// - Parameters:
    ///   - key: Cache key
    ///   - value: Value to cache
    ///   - ttl: Time to live in seconds
    public func set(key: String, value: String, ttl: Int) async throws {
        try await ledger.analyticsCacheSet(key: key, value: value, ttl: ttl)
    }

    /// Deletes a cached entry
    /// - Parameter key: Cache key to delete
    public func delete(key: String) async throws {
        try await ledger.analyticsCacheDelete(key: key)
    }

    /// Cleans up all expired cache entries
    /// - Returns: Number of entries deleted
    @discardableResult
    public func cleanupExpired() async throws -> Int {
        return try await ledger.analyticsCacheCleanup()
    }
}

// MARK: - Errors

public enum CacheError: LocalizedError {
    case unavailable
    case queryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Cache database unavailable"
        case .queryFailed(let message):
            return "Cache query failed: \(message)"
        }
    }
}
