import Foundation

// MARK: - Retry Policy

/// Retry policy configuration for transient network failures.
public struct RetryPolicy: Sendable {
    /// Maximum number of retry attempts
    public let maxAttempts: Int

    /// Base delay between retries (multiplied by 2^n for exponential backoff)
    public let baseDelay: TimeInterval

    /// Maximum delay cap (prevents excessive waits)
    public let maxDelay: TimeInterval

    /// Jitter factor to add randomness (0-1, where 1 = full baseDelay as jitter)
    public let jitterFactor: Double

    /// HTTP status codes that trigger retry
    public let retryableStatusCodes: Set<Int>

    /// URLError codes that trigger retry
    public let retryableErrorCodes: Set<URLError.Code>

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.1,  // 100ms
        maxDelay: TimeInterval = 5.0,
        jitterFactor: Double = 0.1,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
        retryableErrorCodes: Set<URLError.Code> = [
            .timedOut,
            .cannotConnectToHost,
            .networkConnectionLost,
            .notConnectedToInternet,
            .dataNotAllowed
        ]
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterFactor = jitterFactor
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableErrorCodes = retryableErrorCodes
    }

    /// Default retry policy for GET requests (3 attempts, 2^n * 100ms + jitter)
    public static let `default` = RetryPolicy()

    /// Check if an error is retryable based on status code or URLError code
    public func isRetryable(_ error: Error) -> Bool {
        // Check URLError codes
        if let urlError = error as? URLError {
            return retryableErrorCodes.contains(urlError.code)
        }

        // Check HTTP status codes (if wrapped in a known error type)
        // Note: Caller must map HTTP errors to check status codes
        return false
    }

    /// Calculate delay for a given attempt number (0-indexed)
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponentialDelay = min(baseDelay * pow(2, Double(attempt)), maxDelay)
        let jitter = Double.random(in: 0...(baseDelay * jitterFactor))
        return exponentialDelay + jitter
    }

    /// Check if an HTTP status code is retryable
    public func isRetryable(statusCode: Int) -> Bool {
        retryableStatusCodes.contains(statusCode)
    }
}

// MARK: - Retry Result

/// Result of a retry attempt
public enum RetryResult<T: Sendable>: Sendable {
    case success(T)
    case failure(Error)
    case retryAfter(TimeInterval, attempt: Int)

    /// Extract the success value if available
    public var value: T? {
        if case .success(let v) = self { return v }
        return nil
    }
}

// MARK: - Retry Handler

/// Executes async operations with retry logic and exponential backoff.
public actor RetryHandler: Sendable {
    private let policy: RetryPolicy

    public init(policy: RetryPolicy = .default) {
        self.policy = policy
    }

    /// Execute an async operation with retry logic.
    /// - Parameter operation: The operation to execute (should be idempotent)
    /// - Returns: The result of the operation
    /// - Throws: The last error if all retries fail
    public func execute<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<policy.maxAttempts {
            do {
                let result = try await operation()
                // If this was a retry, log it
                if attempt > 0 {
                    // TODO: Log retry attempt to ledger if ledger is available
                }
                return result
            } catch {
                lastError = error

                // Don't retry on the last attempt
                if attempt >= policy.maxAttempts - 1 {
                    break
                }

                // Check if error is retryable
                if !policy.isRetryable(error) {
                    break
                }

                // Calculate delay and wait
                let delay = policy.delay(forAttempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Continue to next attempt
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    /// Execute an HTTP request with retry logic for specific status codes.
    /// - Parameter request: The request to execute (returns (Data, HTTPURLResponse))
    /// - Returns: The tuple of data and response
    /// - Throws: The last error if all retries fail or a non-retryable error occurs
    public func executeHTTP(
        _ request: @escaping @Sendable () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?

        for attempt in 0..<policy.maxAttempts {
            do {
                let (data, response) = try await request()

                // Check if status code is retryable
                if policy.isRetryable(statusCode: response.statusCode) {
                    lastError = RemoteSkillClientError.httpRetryable(statusCode: response.statusCode)
                    // Continue to retry
                } else {
                    return (data, response)
                }
            } catch {
                lastError = error

                // Don't retry on the last attempt
                if attempt >= policy.maxAttempts - 1 {
                    break
                }

                // Check if error is retryable
                if !policy.isRetryable(error) {
                    break
                }
            }

            // Calculate delay and wait
            let delay = policy.delay(forAttempt: attempt)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        throw lastError ?? URLError(.unknown)
    }
}
