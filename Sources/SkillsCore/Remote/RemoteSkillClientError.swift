import Foundation

public enum RemoteSkillClientError: Error, Sendable {
    case notFound
    case httpRetryable(statusCode: Int)
}
