import Foundation

/// Exponential‑backoff retry wrapper used by the API client.
public struct RetryPolicy: Sendable {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval
    public var maxDelay: TimeInterval

    public init(maxAttempts: Int = 3, baseDelay: TimeInterval = 0.4, maxDelay: TimeInterval = 4) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    public static let `default` = RetryPolicy()
    public static let none = RetryPolicy(maxAttempts: 1)

    /// Run `operation`, retrying retryable `PhilipsError`s with backoff + jitter.
    public func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        var attempt = 0
        var lastError: Error = PhilipsError.unknown("no attempts made")
        while attempt < maxAttempts {
            do {
                return try await operation()
            } catch let error as PhilipsError where error.isRetryable && attempt < maxAttempts - 1 {
                lastError = error
                let delay = min(maxDelay, baseDelay * pow(2, Double(attempt)))
                let jitter = Double.random(in: 0...(delay * 0.3))
                try? await Task.sleep(for: .seconds(delay + jitter))
                attempt += 1
            } catch {
                throw error
            }
        }
        throw lastError
    }
}
