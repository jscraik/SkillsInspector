import Foundation

/// Validates regular expressions for safety vulnerabilities
public actor PatternValidator {
    private let maxComplexityScore = 50
    private let maxNestingDepth = 3
    private let dangerousPatterns: Set<String> = [
        #"(?:a+)+"#, #"(?:a*)*"#, #"(?:a+)++"#, #"(.+)+\1"#
    ]

    public func validates(pattern: String) throws -> Bool {
        if dangerousPatterns.contains(pattern) {
            throw ValidationError.knownDangerousPattern(pattern)
        }
        try validateNoNestedQuantifiers(pattern)
        let complexityScore = calculateComplexityScore(pattern)
        if complexityScore > maxComplexityScore {
            throw ValidationError.complexityTooHigh(complexityScore, max: maxComplexityScore)
        }
        _ = try NSRegularExpression(pattern: pattern, options: [])
        return true
    }

    public func validatedRegex(pattern: String) throws -> NSRegularExpression {
        guard try validates(pattern: pattern) else { throw ValidationError.invalidPattern(nil) }
        return try NSRegularExpression(pattern: pattern, options: [])
    }

    private func validateNoNestedQuantifiers(_ pattern: String) throws {
        var depth = 0
        var i = pattern.startIndex
        while i < pattern.endIndex {
            let char = pattern[i]
            if char == "(" {
                depth += 1
            } else if char == ")" {
                depth = max(0, depth - 1)
            }
            if depth > maxNestingDepth {
                throw ValidationError.nestingTooDeep(depth, max: maxNestingDepth)
            }
            i = pattern.index(after: i)
        }
    }

    private func calculateComplexityScore(_ pattern: String) -> Int {
        var score = 0
        for char in pattern where "*+?".contains(char) { score += 5 }
        score += pattern.components(separatedBy: "(").count * 3
        score += pattern.components(separatedBy: "[").count * 2
        score += pattern.components(separatedBy: "|").count * 10
        return score
    }
}

public enum ValidationError: Error, LocalizedError {
    case knownDangerousPattern(String)
    case nestedQuantifiers(String)
    case nestingTooDeep(Int, max: Int)
    case complexityTooHigh(Int, max: Int)
    case invalidPattern(Error?)

    public var errorDescription: String? {
        switch self {
        case .knownDangerousPattern(let p): return "Pattern '\(p)' is vulnerable to ReDoS"
        case .nestedQuantifiers(let s): return "Nested quantifiers: '\(s)'"
        case .nestingTooDeep(let d, let m): return "Nesting depth \(d) exceeds \(m)"
        case .complexityTooHigh(let s, let m): return "Complexity \(s) exceeds \(m)"
        case .invalidPattern(let e): return "Invalid regex: \(e?.localizedDescription ?? "unknown")"
        }
    }
}
