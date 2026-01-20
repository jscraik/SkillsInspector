import Foundation

// MARK: - Circuit Breaker

/// Circuit breaker state machine for preventing cascading failures.
public actor CircuitBreaker: Sendable {
    /// Circuit breaker states
    public enum State: Sendable {
        case closed           // Normal operation, requests pass through
        case open             // Circuit is tripped, requests fail fast
        case halfOpen         // Testing if service has recovered
    }

    /// Circuit breaker configuration
    public struct Configuration: Sendable {
        /// Number of consecutive failures before tripping the circuit
        public let failureThreshold: Int

        /// Number of consecutive successes before closing the circuit (from half-open)
        public let successThreshold: Int

        /// How long to stay open before attempting recovery
        public let openTimeout: TimeInterval

        /// How long to stay in half-open before giving up
        public let halfOpenTimeout: TimeInterval

        public init(
            failureThreshold: Int = 5,
            successThreshold: Int = 2,
            openTimeout: TimeInterval = 60.0,
            halfOpenTimeout: TimeInterval = 30.0
        ) {
            self.failureThreshold = failureThreshold
            self.successThreshold = successThreshold
            self.openTimeout = openTimeout
            self.halfOpenTimeout = halfOpenTimeout
        }
    }

    /// Circuit breaker execution result
    public enum ExecutionResult<T: Sendable>: Sendable {
        case success(T)
        case failure(Error)
        case rejected(State)  // Request was rejected by the circuit breaker

        public var value: T? {
            if case .success(let v) = self { return v }
            return nil
        }
    }

    // MARK: - Properties

    private var state: State = .closed
    private var failureCount: Int = 0
    private var successCount: Int = 0
    private var lastFailureTime: Date?
    private var lastStateChange: Date = Date()

    private let config: Configuration

    public init(config: Configuration = .default) {
        self.config = config
    }

    // MARK: - Public Interface

    /// Get the current circuit breaker state
    public var currentState: State {
        // Auto-transition from open to half-open after timeout
        if case .open = state,
           let lastFailure = lastFailureTime,
           Date().timeIntervalSince(lastFailure) >= config.openTimeout {
            transitionTo(.halfOpen)
        }

        // Auto-transition from half-open to closed after timeout (recovery failed)
        if case .halfOpen = state,
           Date().timeIntervalSince(lastStateChange) >= config.halfOpenTimeout {
            transitionTo(.open)  // Recovery failed, trip again
        }

        return state
    }

    /// Execute an operation through the circuit breaker.
    /// - Parameter operation: The operation to execute
    /// - Returns: ExecutionResult indicating success, failure, or rejection
    public func execute<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async -> ExecutionResult<T> {
        switch currentState {
        case .open:
            return .rejected(.open)

        case .halfOpen, .closed:
            break
        }

        do {
            let result = try await operation()
            recordSuccess()
            return .success(result)
        } catch {
            recordFailure()
            return .failure(error)
        }
    }

    /// Manually trip the circuit breaker (use for external signals)
    public func trip() {
        transitionTo(.open)
    }

    /// Manually reset the circuit breaker to closed state
    public func reset() {
        transitionTo(.closed)
        failureCount = 0
        successCount = 0
        lastFailureTime = nil
    }

    /// Get statistics about the circuit breaker
    public var stats: Stats {
        Stats(
            state: currentState,
            failureCount: failureCount,
            successCount: successCount,
            lastFailureTime: lastFailureTime,
            lastStateChange: lastStateChange
        )
    }

    // MARK: - Private Methods

    private func recordSuccess() {
        switch currentState {
        case .closed:
            failureCount = 0

        case .halfOpen:
            successCount += 1
            if successCount >= config.successThreshold {
                transitionTo(.closed)
            }

        case .open:
            break
        }
    }

    private func recordFailure() {
        lastFailureTime = Date()

        switch currentState {
        case .closed, .halfOpen:
            failureCount += 1
            if failureCount >= config.failureThreshold {
                transitionTo(.open)
            } else if case .halfOpen = currentState {
                // Recovery failed, go back to open
                transitionTo(.open)
            }

        case .open:
            // Already open, just update timestamp
            break
        }
    }

    private func transitionTo(_ newState: State) {
        state = newState
        lastStateChange = Date()

        // Reset counters on state change
        switch newState {
        case .closed:
            failureCount = 0
            successCount = 0

        case .open:
            successCount = 0

        case .halfOpen:
            failureCount = 0
        }
    }

    /// Check if the circuit breaker allows requests
    public var allowsRequests: Bool {
        switch currentState {
        case .closed, .halfOpen:
            return true
        case .open:
            return false
        }
    }
}

// MARK: - Circuit Breaker Stats

/// Statistics about the circuit breaker state
public struct CircuitBreakerStats: Sendable {
    public let state: CircuitBreaker.State
    public let failureCount: Int
    public let successCount: Int
    public let lastFailureTime: Date?
    public let lastStateChange: Date
}

extension CircuitBreaker {
    public typealias Stats = CircuitBreakerStats
}

// MARK: - Default Configuration

extension CircuitBreaker.Configuration {
    /// Default configuration: trip after 5 failures, open for 60s
    public static let `default` = CircuitBreaker.Configuration()
}

// MARK: - Per-Host Circuit Breaker Registry

/// Registry of circuit breakers keyed by host
public actor CircuitBreakerRegistry: Sendable {
    private var breakers: [String: CircuitBreaker] = [:]

    /// Get or create a circuit breaker for a specific host
    public func breaker(for host: String, config: CircuitBreaker.Configuration = .default) -> CircuitBreaker {
        if let existing = breakers[host] {
            return existing
        }
        let newBreaker = CircuitBreaker(config: config)
        breakers[host] = newBreaker
        return newBreaker
    }

    /// Reset a specific circuit breaker
    public func reset(for host: String) async {
        await breakers[host]?.reset()
    }

    /// Get all circuit breaker stats
    public func allStats() async -> [String: CircuitBreaker.Stats] {
        var stats: [String: CircuitBreaker.Stats] = [:]
        for (host, breaker) in breakers {
            stats[host] = await breaker.stats
        }
        return stats
    }
}
