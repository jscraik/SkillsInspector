import Foundation

/// Protects against ReDoS (Regular Expression Denial of Service) attacks
public actor ReDoSProtector {
    private let maxMatches: Int = 1000

    public func safeMatch(
        _ pattern: NSRegularExpression,
        in string: String,
        timeout: TimeInterval = 5.0
    ) throws -> [NSTextCheckingResult] {
        let range = NSRange(location: 0, length: string.utf16.count)
        let matches = pattern.matches(in: string, range: range)
        return Array(matches.prefix(self.maxMatches))
    }

    public func safeFirstMatch(
        _ pattern: NSRegularExpression,
        in string: String,
        timeout: TimeInterval = 5.0
    ) throws -> NSTextCheckingResult? {
        let matches = try safeMatch(pattern, in: string, timeout: timeout)
        return matches.first
    }

    public func safeContains(
        _ pattern: NSRegularExpression,
        in string: String,
        timeout: TimeInterval = 5.0
    ) throws -> Bool {
        return try safeFirstMatch(pattern, in: string, timeout: timeout) != nil
    }

    public func complexityScore(for pattern: String) -> Int {
        var score = 0
        let nestedQuantifierPattern = #"(\*|\+|\?|\{[\d,]+\})(\*|\+|\?|\{[\d,]+\})"#
        if let regex = try? NSRegularExpression(pattern: nestedQuantifierPattern),
           let _ = regex.firstMatch(in: pattern, range: NSRange(pattern.startIndex..., in: pattern)) {
            score += 100
        }
        let alternationCount = pattern.components(separatedBy: "|").count - 1
        score += alternationCount * 10
        return score
    }

    public func isSafePattern(_ pattern: String) -> Bool {
        return complexityScore(for: pattern) < 30
    }
}

public enum ReDoSError: Error, LocalizedError {
    case timeoutExceeded(TimeInterval)
    case tooManyMatches(Int, max: Int)
    case patternTooComplex(Int)
    case unknownError

    public var errorDescription: String? {
        switch self {
        case .timeoutExceeded(let timeout):
            return "Regex operation exceeded timeout of \(timeout) seconds"
        case .tooManyMatches(let count, let max):
            return "Pattern matched \(count) times, truncated to \(max)"
        case .patternTooComplex(let score):
            return "Pattern complexity score \(score) is too high"
        case .unknownError:
            return "Unknown error during regex operation"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .timeoutExceeded:
            return "Simplify the regex pattern"
        case .tooManyMatches:
            return "Consider using more specific patterns"
        case .patternTooComplex:
            return "Break the pattern into simpler components"
        case .unknownError:
            return "Check the regex syntax"
        }
    }
}
