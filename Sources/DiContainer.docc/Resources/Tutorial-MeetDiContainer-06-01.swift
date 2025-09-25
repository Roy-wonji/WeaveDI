import Foundation
import DiContainer
import LogMacro

// MARK: - Mock Services for Testing

/// 테스트용 CounterService Mock
final class MockCounterService: CounterService, @unchecked Sendable {
    private var _count = 0
    private let accessQueue = DispatchQueue(label: "MockCounterService.access", attributes: .concurrent)

    var incrementCallCount = 0
    var decrementCallCount = 0
    var resetCallCount = 0

    var count: Int {
        accessQueue.sync { _count }
    }

    func increment() {
        accessQueue.async(flags: .barrier) {
            self._count += 1
            self.incrementCallCount += 1
            #logInfo("🧪 [Mock] Counter incremented to \(self._count) (call count: \(self.incrementCallCount))")
        }
    }

    func decrement() {
        accessQueue.async(flags: .barrier) {
            self._count -= 1
            self.decrementCallCount += 1
            #logInfo("🧪 [Mock] Counter decremented to \(self._count) (call count: \(self.decrementCallCount))")
        }
    }

    func reset() {
        accessQueue.async(flags: .barrier) {
            self._count = 0
            self.resetCallCount += 1
            #logInfo("🧪 [Mock] Counter reset to 0 (call count: \(self.resetCallCount))")
        }
    }

    // Test helper methods
    func setCount(_ newCount: Int) {
        accessQueue.async(flags: .barrier) {
            self._count = newCount
        }
    }

    func resetCallCounts() {
        accessQueue.async(flags: .barrier) {
            self.incrementCallCount = 0
            self.decrementCallCount = 0
            self.resetCallCount = 0
        }
    }
}

// MARK: - Mock LoggingService

/// 테스트용 LoggingService Mock
final class MockLoggingService: LoggingService, @unchecked Sendable {
    private var _logs: [String] = []
    private let accessQueue = DispatchQueue(label: "MockLoggingService.access", attributes: .concurrent)

    var sessionId: String = "mock-session-\(UUID().uuidString.prefix(8))"

    var logs: [String] {
        accessQueue.sync { _logs }
    }

    var logCallCount: Int {
        accessQueue.sync { _logs.count }
    }

    func log(_ message: String) {
        accessQueue.async(flags: .barrier) {
            let logEntry = "[\(self.sessionId)] \(message)"
            self._logs.append(logEntry)
            #logInfo("📝 [Mock] Log recorded: \(logEntry)")
        }
    }

    func getLogs() -> [String] {
        accessQueue.sync { _logs }
    }

    func startNewSession() {
        accessQueue.async(flags: .barrier) {
            self.sessionId = "mock-session-\(UUID().uuidString.prefix(8))"
            #logInfo("🔄 [Mock] New session started: \(self.sessionId)")
        }
    }

    // Test helper methods
    func clearLogs() {
        accessQueue.async(flags: .barrier) {
            self._logs.removeAll()
        }
    }

    func getLastLog() -> String? {
        accessQueue.sync { _logs.last }
    }
}

// MARK: - Mock NetworkService

/// 테스트용 NetworkService Mock (실패 시나리오 테스트용)
final class MockNetworkService: NetworkService, @unchecked Sendable {
    private let accessQueue = DispatchQueue(label: "MockNetworkService.access", attributes: .concurrent)

    var shouldFail = false
    var requestCount = 0
    var lastUrl: String?

    func fetchData(from url: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            accessQueue.async(flags: .barrier) {
                self.requestCount += 1
                self.lastUrl = url

                #logInfo("🌐 [Mock] Network request #\(self.requestCount) to: \(url)")

                if self.shouldFail {
                    #logError("❌ [Mock] Network request failed (simulated)")
                    continuation.resume(throwing: MockNetworkError.simulatedFailure)
                } else {
                    let response = "Mock response for: \(url)"
                    #logInfo("✅ [Mock] Network response: \(response)")
                    continuation.resume(returning: response)
                }
            }
        }
    }

    // Test helper methods
    func simulateFailure() {
        accessQueue.async(flags: .barrier) {
            self.shouldFail = true
        }
    }

    func simulateSuccess() {
        accessQueue.async(flags: .barrier) {
            self.shouldFail = false
        }
    }

    func resetStats() {
        accessQueue.async(flags: .barrier) {
            self.requestCount = 0
            self.lastUrl = nil
            self.shouldFail = false
        }
    }

    func getRequestCount() -> Int {
        accessQueue.sync { requestCount }
    }
}

// MARK: - Mock Repository Layer

/// 테스트용 CounterRepository Mock
final class MockCounterRepository: CounterRepository, @unchecked Sendable {
    private var _currentValue = 0
    private let accessQueue = DispatchQueue(label: "MockCounterRepository.access", attributes: .concurrent)

    var saveCallCount = 0
    var loadCallCount = 0
    var shouldFailOnSave = false
    var shouldFailOnLoad = false

    var currentValue: Int {
        accessQueue.sync { _currentValue }
    }

    func save(value: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            accessQueue.async(flags: .barrier) {
                self.saveCallCount += 1

                if self.shouldFailOnSave {
                    #logError("❌ [Mock Repository] Save failed (simulated)")
                    continuation.resume(throwing: MockRepositoryError.saveFailed)
                } else {
                    self._currentValue = value
                    #logInfo("💾 [Mock Repository] Saved value: \(value) (call count: \(self.saveCallCount))")
                    continuation.resume()
                }
            }
        }
    }

    func load() async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            accessQueue.sync {
                self.loadCallCount += 1

                if self.shouldFailOnLoad {
                    #logError("❌ [Mock Repository] Load failed (simulated)")
                    continuation.resume(throwing: MockRepositoryError.loadFailed)
                } else {
                    #logInfo("📖 [Mock Repository] Loaded value: \(self._currentValue) (call count: \(self.loadCallCount))")
                    continuation.resume(returning: self._currentValue)
                }
            }
        }
    }

    // Test helper methods
    func setValue(_ value: Int) {
        accessQueue.async(flags: .barrier) {
            self._currentValue = value
        }
    }

    func simulateSaveFailure() {
        accessQueue.async(flags: .barrier) {
            self.shouldFailOnSave = true
        }
    }

    func simulateLoadFailure() {
        accessQueue.async(flags: .barrier) {
            self.shouldFailOnLoad = true
        }
    }

    func resetToSuccessMode() {
        accessQueue.async(flags: .barrier) {
            self.shouldFailOnSave = false
            self.shouldFailOnLoad = false
        }
    }

    func resetCallCounts() {
        accessQueue.async(flags: .barrier) {
            self.saveCallCount = 0
            self.loadCallCount = 0
        }
    }
}

// MARK: - Mock UseCase Layer

/// 테스트용 CounterUseCase Mock
final class MockCounterUseCase: CounterUseCase, @unchecked Sendable {
    private var _value = 0
    private let accessQueue = DispatchQueue(label: "MockCounterUseCase.access", attributes: .concurrent)

    var incrementCallCount = 0
    var decrementCallCount = 0
    var currentValueCallCount = 0
    var shouldFailOnIncrement = false
    var shouldFailOnDecrement = false

    var currentValue: Int {
        accessQueue.sync {
            currentValueCallCount += 1
            return _value
        }
    }

    func increment() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            accessQueue.async(flags: .barrier) {
                self.incrementCallCount += 1

                if self.shouldFailOnIncrement {
                    #logError("❌ [Mock UseCase] Increment failed (simulated)")
                    continuation.resume(throwing: MockUseCaseError.incrementFailed)
                } else {
                    self._value += 1
                    #logInfo("⬆️ [Mock UseCase] Incremented to: \(self._value) (call count: \(self.incrementCallCount))")
                    continuation.resume()
                }
            }
        }
    }

    func decrement() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            accessQueue.async(flags: .barrier) {
                self.decrementCallCount += 1

                if self.shouldFailOnDecrement {
                    #logError("❌ [Mock UseCase] Decrement failed (simulated)")
                    continuation.resume(throwing: MockUseCaseError.decrementFailed)
                } else {
                    self._value -= 1
                    #logInfo("⬇️ [Mock UseCase] Decremented to: \(self._value) (call count: \(self.decrementCallCount))")
                    continuation.resume()
                }
            }
        }
    }

    // Test helper methods
    func setValue(_ value: Int) {
        accessQueue.async(flags: .barrier) {
            self._value = value
        }
    }

    func simulateIncrementFailure() {
        accessQueue.async(flags: .barrier) {
            self.shouldFailOnIncrement = true
        }
    }

    func simulateDecrementFailure() {
        accessQueue.async(flags: .barrier) {
            self.shouldFailOnDecrement = true
        }
    }

    func resetToSuccessMode() {
        accessQueue.async(flags: .barrier) {
            self.shouldFailOnIncrement = false
            self.shouldFailOnDecrement = false
        }
    }

    func resetCallCounts() {
        accessQueue.async(flags: .barrier) {
            self.incrementCallCount = 0
            self.decrementCallCount = 0
            self.currentValueCallCount = 0
        }
    }
}

// MARK: - Mock Error Types

enum MockNetworkError: Error, LocalizedError {
    case simulatedFailure

    var errorDescription: String? {
        switch self {
        case .simulatedFailure:
            return "Simulated network failure for testing"
        }
    }
}

enum MockRepositoryError: Error, LocalizedError {
    case saveFailed
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Simulated repository save failure"
        case .loadFailed:
            return "Simulated repository load failure"
        }
    }
}

enum MockUseCaseError: Error, LocalizedError {
    case incrementFailed
    case decrementFailed

    var errorDescription: String? {
        switch self {
        case .incrementFailed:
            return "Simulated use case increment failure"
        case .decrementFailed:
            return "Simulated use case decrement failure"
        }
    }
}

// MARK: - Test Helper Extensions

extension MockCounterService {
    /// 빠른 테스트 설정을 위한 편의 메서드
    static func createForTesting(initialCount: Int = 0) -> MockCounterService {
        let mock = MockCounterService()
        mock.setCount(initialCount)
        return mock
    }
}

extension MockLoggingService {
    /// 빠른 테스트 설정을 위한 편의 메서드
    static func createForTesting(sessionId: String? = nil) -> MockLoggingService {
        let mock = MockLoggingService()
        if let sessionId = sessionId {
            mock.sessionId = sessionId
        }
        return mock
    }
}

extension MockCounterRepository {
    /// 빠른 테스트 설정을 위한 편의 메서드
    static func createForTesting(initialValue: Int = 0) -> MockCounterRepository {
        let mock = MockCounterRepository()
        mock.setValue(initialValue)
        return mock
    }
}