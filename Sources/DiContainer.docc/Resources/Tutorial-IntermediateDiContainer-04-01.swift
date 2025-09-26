import Foundation
import DiContainer
import LogMacro

// MARK: - 프로덕션 환경 에러 처리 및 복구

/// 실제 프로덕션 환경에서 발생할 수 있는 의존성 주입 관련 오류들을
/// 안전하게 처리하고 복구하는 전략들을 구현합니다.

// MARK: - 에러 유형 정의

enum DIError: Error, LocalizedError {
    case dependencyNotFound(String)
    case circularDependency([String])
    case factoryExecutionFailed(String, Error)
    case scopeNotAvailable(String)
    case containerLocked
    case initializationTimeout(String, TimeInterval)
    case memoryPressure
    case threadingViolation(String)

    var errorDescription: String? {
        switch self {
        case .dependencyNotFound(let type):
            return "의존성을 찾을 수 없습니다: \(type)"
        case .circularDependency(let cycle):
            return "순환 의존성이 감지됨: \(cycle.joined(separator: " → "))"
        case .factoryExecutionFailed(let type, let underlyingError):
            return "팩토리 실행 실패 (\(type)): \(underlyingError.localizedDescription)"
        case .scopeNotAvailable(let scope):
            return "스코프를 사용할 수 없음: \(scope)"
        case .containerLocked:
            return "컨테이너가 잠겨있습니다"
        case .initializationTimeout(let type, let timeout):
            return "초기화 시간 초과 (\(type)): \(timeout)초"
        case .memoryPressure:
            return "메모리 부족으로 인한 의존성 해결 제한"
        case .threadingViolation(let description):
            return "스레딩 위반: \(description)"
        }
    }

    var severity: ErrorSeverity {
        switch self {
        case .dependencyNotFound, .scopeNotAvailable:
            return .warning
        case .circularDependency, .containerLocked, .threadingViolation:
            return .error
        case .factoryExecutionFailed, .initializationTimeout:
            return .critical
        case .memoryPressure:
            return .severe
        }
    }
}

enum ErrorSeverity: Int, Comparable {
    case info = 0
    case warning = 1
    case error = 2
    case critical = 3
    case severe = 4

    static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        case .severe: return "💀"
        }
    }
}

// MARK: - Fallback 전략

protocol FallbackStrategy {
    func canHandle(_ error: DIError) -> Bool
    func resolve<T>(_ type: T.Type, originalError: DIError) -> T?
}

/// 기본값을 제공하는 Fallback 전략
final class DefaultValueFallbackStrategy: FallbackStrategy {
    private var defaultValues: [String: Any] = [:]

    func registerDefaultValue<T>(_ value: T, for type: T.Type) {
        let key = String(describing: type)
        defaultValues[key] = value
        #logInfo("🔄 기본값 등록: \(key)")
    }

    func canHandle(_ error: DIError) -> Bool {
        switch error {
        case .dependencyNotFound, .factoryExecutionFailed, .scopeNotAvailable:
            return true
        default:
            return false
        }
    }

    func resolve<T>(_ type: T.Type, originalError: DIError) -> T? {
        let key = String(describing: type)
        if let defaultValue = defaultValues[key] as? T {
            #logWarning("🔄 기본값 사용: \(key) (원인: \(originalError.localizedDescription))")
            return defaultValue
        }
        return nil
    }
}

/// Mock 객체를 제공하는 Fallback 전략
final class MockFallbackStrategy: FallbackStrategy {
    private var mockFactories: [String: () -> Any] = [:]

    func registerMockFactory<T>(_ factory: @escaping () -> T, for type: T.Type) {
        let key = String(describing: type)
        mockFactories[key] = factory
        #logInfo("🎭 Mock 팩토리 등록: \(key)")
    }

    func canHandle(_ error: DIError) -> Bool {
        switch error {
        case .dependencyNotFound, .factoryExecutionFailed, .circularDependency:
            return true
        default:
            return false
        }
    }

    func resolve<T>(_ type: T.Type, originalError: DIError) -> T? {
        let key = String(describing: type)
        if let mockFactory = mockFactories[key] {
            #logWarning("🎭 Mock 객체 사용: \(key) (원인: \(originalError.localizedDescription))")
            return mockFactory() as? T
        }
        return nil
    }
}

/// 지연된 초기화를 제공하는 Fallback 전략
final class LazyInitFallbackStrategy: FallbackStrategy {
    private var retryQueue = DispatchQueue(label: "LazyInitFallback", qos: .utility)
    private var retryScheduler: [String: Timer] = [:]

    func canHandle(_ error: DIError) -> Bool {
        switch error {
        case .initializationTimeout, .factoryExecutionFailed, .memoryPressure:
            return true
        default:
            return false
        }
    }

    func resolve<T>(_ type: T.Type, originalError: DIError) -> T? {
        let key = String(describing: type)

        #logWarning("⏱️ 지연된 초기화 스케줄링: \(key)")

        // 5초 후 재시도 스케줄링
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            self.retryInitialization(for: key)
            self.retryScheduler.removeValue(forKey: key)
        }

        retryScheduler[key] = timer
        return nil // 즉시 반환하지 않음
    }

    private func retryInitialization(for key: String) {
        #logInfo("🔄 재시도 초기화: \(key)")
        // 실제 구현에서는 원본 팩토리를 다시 실행
    }
}

// MARK: - 에러 복구 시스템

final class DIErrorRecoverySystem: @unchecked Sendable {
    private let queue = DispatchQueue(label: "DIErrorRecoverySystem", attributes: .concurrent)

    private var _fallbackStrategies: [FallbackStrategy] = []
    private var _errorHistory: [ErrorRecord] = []
    private var _circuitBreakers: [String: CircuitBreaker] = [:]

    private struct ErrorRecord {
        let error: DIError
        let timestamp: Date
        let context: String
        let resolved: Bool
    }

    /// Fallback 전략을 등록합니다
    func registerFallbackStrategy(_ strategy: FallbackStrategy) {
        queue.async(flags: .barrier) {
            self._fallbackStrategies.append(strategy)
        }
        #logInfo("🛡️ Fallback 전략 등록: \(type(of: strategy))")
    }

    /// 에러 발생시 복구를 시도합니다
    func attemptRecovery<T>(_ error: DIError, for type: T.Type, context: String = "") -> T? {
        #logError("\(error.severity.emoji) DI 에러 발생: \(error.localizedDescription)")

        let result = queue.sync {
            // Circuit Breaker 확인
            let key = String(describing: type)
            if let circuitBreaker = _circuitBreakers[key], circuitBreaker.isOpen {
                #logError("🚫 Circuit Breaker 열림: \(key)")
                return nil
            }

            // Fallback 전략들 시도
            for strategy in _fallbackStrategies {
                if strategy.canHandle(error) {
                    if let fallbackValue = strategy.resolve(type, originalError: error) {
                        recordError(error, context: context, resolved: true)
                        return fallbackValue
                    }
                }
            }

            recordError(error, context: context, resolved: false)

            // Circuit Breaker 업데이트
            updateCircuitBreaker(for: key, success: false)
            return nil
        }

        return result
    }

    private func recordError(_ error: DIError, context: String, resolved: Bool) {
        let record = ErrorRecord(
            error: error,
            timestamp: Date(),
            context: context,
            resolved: resolved
        )

        _errorHistory.append(record)

        // 최근 1000개 기록만 유지
        if _errorHistory.count > 1000 {
            _errorHistory = Array(_errorHistory.suffix(1000))
        }

        #logInfo("📝 에러 기록: \(error.errorDescription ?? "Unknown") (해결됨: \(resolved))")
    }

    private func updateCircuitBreaker(for key: String, success: Bool) {
        if _circuitBreakers[key] == nil {
            _circuitBreakers[key] = CircuitBreaker(failureThreshold: 5, recoveryTimeout: 60.0)
        }

        if success {
            _circuitBreakers[key]?.recordSuccess()
        } else {
            _circuitBreakers[key]?.recordFailure()
        }
    }

    /// 성공적인 해결을 기록합니다
    func recordSuccess<T>(for type: T.Type) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.updateCircuitBreaker(for: key, success: true)
        }
    }

    /// 에러 통계를 반환합니다
    func getErrorStatistics() -> ErrorStatistics {
        return queue.sync {
            let totalErrors = _errorHistory.count
            let resolvedErrors = _errorHistory.filter { $0.resolved }.count
            let recentErrors = _errorHistory.filter {
                Date().timeIntervalSince($0.timestamp) < 3600 // 최근 1시간
            }

            let errorsByType = Dictionary(grouping: _errorHistory) { record in
                String(describing: type(of: record.error))
            }

            return ErrorStatistics(
                totalErrors: totalErrors,
                resolvedErrors: resolvedErrors,
                recentErrors: recentErrors.count,
                resolutionRate: totalErrors > 0 ? Double(resolvedErrors) / Double(totalErrors) : 0.0,
                errorsByType: errorsByType.mapValues { $0.count },
                activeCircuitBreakers: _circuitBreakers.filter { $0.value.isOpen }.count
            )
        }
    }
}

struct ErrorStatistics {
    let totalErrors: Int
    let resolvedErrors: Int
    let recentErrors: Int
    let resolutionRate: Double
    let errorsByType: [String: Int]
    let activeCircuitBreakers: Int
}

// MARK: - Circuit Breaker

final class CircuitBreaker {
    private enum State {
        case closed    // 정상 동작
        case open      // 차단됨
        case halfOpen  // 복구 시도 중
    }

    private var state: State = .closed
    private var failureCount: Int = 0
    private let failureThreshold: Int
    private let recoveryTimeout: TimeInterval
    private var lastFailureTime: Date?

    var isOpen: Bool { state == .open }

    init(failureThreshold: Int, recoveryTimeout: TimeInterval) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
    }

    func recordSuccess() {
        state = .closed
        failureCount = 0
        lastFailureTime = nil
        #logInfo("✅ Circuit Breaker 성공 기록 - 상태: 닫힘")
    }

    func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()

        if failureCount >= failureThreshold {
            state = .open
            #logWarning("🚫 Circuit Breaker 열림 - 실패 횟수: \(failureCount)")
        }
    }

    func canAttempt() -> Bool {
        switch state {
        case .closed:
            return true
        case .open:
            // 복구 시간이 지났으면 half-open으로 전환
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > recoveryTimeout {
                state = .halfOpen
                #logInfo("🔄 Circuit Breaker 반개방 - 복구 시도 중")
                return true
            }
            return false
        case .halfOpen:
            return true
        }
    }
}

// MARK: - 실용적인 에러 처리 예제들

// 안전한 서비스들 (Fallback 대상)

protocol DatabaseService: Sendable {
    func getData(id: String) async throws -> String
    func saveData(id: String, data: String) async throws
}

final class RealDatabaseService: DatabaseService {
    func getData(id: String) async throws -> String {
        // 실제 데이터베이스 연결이 실패할 수 있음
        throw DIError.factoryExecutionFailed("DatabaseService", NSError(domain: "DB", code: 500))
    }

    func saveData(id: String, data: String) async throws {
        throw DIError.factoryExecutionFailed("DatabaseService", NSError(domain: "DB", code: 500))
    }
}

final class MockDatabaseService: DatabaseService {
    private var mockData: [String: String] = [
        "user1": "Mock User Data",
        "user2": "Another Mock Data"
    ]

    func getData(id: String) async throws -> String {
        #logInfo("🎭 Mock Database - 데이터 조회: \(id)")
        return mockData[id] ?? "Mock Default Data"
    }

    func saveData(id: String, data: String) async throws {
        #logInfo("🎭 Mock Database - 데이터 저장: \(id)")
        mockData[id] = data
    }
}

protocol CacheService: Sendable {
    func get(key: String) async -> String?
    func set(key: String, value: String) async
}

final class RedisCacheService: CacheService {
    func get(key: String) async -> String? {
        #logWarning("🔴 Redis 연결 실패")
        return nil
    }

    func set(key: String, value: String) async {
        #logWarning("🔴 Redis 연결 실패")
    }
}

final class InMemoryCacheService: CacheService {
    private var cache: [String: String] = [:]

    func get(key: String) async -> String? {
        #logInfo("💾 InMemory Cache - 조회: \(key)")
        return cache[key]
    }

    func set(key: String, value: String) async {
        #logInfo("💾 InMemory Cache - 저장: \(key)")
        cache[key] = value
    }
}

// MARK: - 에러 처리 시스템 설정

extension DIContainer {
    /// 프로덕션 환경 에러 처리 시스템을 설정합니다
    func setupProductionErrorHandling() {
        let errorRecovery = DIErrorRecoverySystem()

        // Fallback 전략들 등록
        let defaultStrategy = DefaultValueFallbackStrategy()
        defaultStrategy.registerDefaultValue("", for: String.self)
        defaultStrategy.registerDefaultValue(0, for: Int.self)
        defaultStrategy.registerDefaultValue(false, for: Bool.self)

        let mockStrategy = MockFallbackStrategy()
        mockStrategy.registerMockFactory({ MockDatabaseService() }, for: DatabaseService.self)
        mockStrategy.registerMockFactory({ InMemoryCacheService() }, for: CacheService.self)

        let lazyStrategy = LazyInitFallbackStrategy()

        errorRecovery.registerFallbackStrategy(defaultStrategy)
        errorRecovery.registerFallbackStrategy(mockStrategy)
        errorRecovery.registerFallbackStrategy(lazyStrategy)

        registerSingleton(DIErrorRecoverySystem.self) { errorRecovery }

        #logInfo("🛡️ 프로덕션 에러 처리 시스템 설정 완료")
    }

    /// 안전한 의존성 해결 (에러 복구 포함)
    func safeResolve<T>(_ type: T.Type, context: String = "") -> T? {
        do {
            let instance: T = resolve()
            let errorRecovery: DIErrorRecoverySystem = resolve()
            errorRecovery.recordSuccess(for: type)
            return instance
        } catch let error as DIError {
            let errorRecovery: DIErrorRecoverySystem = resolve()
            return errorRecovery.attemptRecovery(error, for: type, context: context)
        } catch {
            let diError = DIError.factoryExecutionFailed(String(describing: type), error)
            let errorRecovery: DIErrorRecoverySystem = resolve()
            return errorRecovery.attemptRecovery(diError, for: type, context: context)
        }
    }
}

// MARK: - 에러 처리 데모

final class ProductionErrorHandlingDemo {
    private let container = DIContainer()

    init() {
        container.setupProductionErrorHandling()
        setupServices()
    }

    private func setupServices() {
        // 실패할 가능성이 있는 실제 서비스들 등록
        container.register(DatabaseService.self) {
            RealDatabaseService() // 항상 실패
        }

        container.register(CacheService.self) {
            RedisCacheService() // 연결 실패
        }
    }

    func demonstrateErrorHandling() async {
        #logInfo("🎬 프로덕션 에러 처리 데모 시작")

        await testDatabaseServiceFallback()
        await testCacheServiceFallback()
        await testCircuitBreakerBehavior()
        showErrorStatistics()

        #logInfo("🎉 프로덕션 에러 처리 데모 완료")
    }

    private func testDatabaseServiceFallback() async {
        #logInfo("\n1️⃣ 데이터베이스 서비스 Fallback 테스트")

        if let dbService = container.safeResolve(DatabaseService.self, context: "user_data_access") {
            do {
                let userData = try await dbService.getData(id: "user1")
                #logInfo("✅ 데이터 조회 성공: \(userData)")

                try await dbService.saveData(id: "user2", data: "New User Data")
                #logInfo("✅ 데이터 저장 성공")
            } catch {
                #logError("❌ 데이터베이스 작업 실패: \(error)")
            }
        } else {
            #logError("❌ 데이터베이스 서비스를 해결할 수 없음")
        }
    }

    private func testCacheServiceFallback() async {
        #logInfo("\n2️⃣ 캐시 서비스 Fallback 테스트")

        if let cacheService = container.safeResolve(CacheService.self, context: "cache_access") {
            await cacheService.set(key: "session_token", value: "abc123")

            if let token = await cacheService.get(key: "session_token") {
                #logInfo("✅ 캐시 조회 성공: \(token)")
            } else {
                #logInfo("ℹ️ 캐시 미스")
            }
        } else {
            #logError("❌ 캐시 서비스를 해결할 수 없음")
        }
    }

    private func testCircuitBreakerBehavior() async {
        #logInfo("\n3️⃣ Circuit Breaker 동작 테스트")

        // 연속적인 실패로 Circuit Breaker 열기
        for i in 1...7 {
            #logInfo("시도 #\(i)")
            _ = container.safeResolve(DatabaseService.self, context: "circuit_breaker_test")
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
        }
    }

    private func showErrorStatistics() {
        #logInfo("\n📊 에러 통계")

        let errorRecovery: DIErrorRecoverySystem = container.resolve()
        let stats = errorRecovery.getErrorStatistics()

        #logInfo("- 총 에러 수: \(stats.totalErrors)")
        #logInfo("- 해결된 에러 수: \(stats.resolvedErrors)")
        #logInfo("- 최근 에러 수: \(stats.recentErrors)")
        #logInfo("- 해결률: \(String(format: "%.1f", stats.resolutionRate * 100))%")
        #logInfo("- 활성 Circuit Breaker: \(stats.activeCircuitBreakers)개")

        if !stats.errorsByType.isEmpty {
            #logInfo("- 에러 유형별:")
            for (type, count) in stats.errorsByType {
                #logInfo("  - \(type): \(count)회")
            }
        }
    }
}

// MARK: - 프로덕션 에러 처리 데모

enum ProductionErrorHandlingExample {
    static func demonstrateProductionErrorHandling() async {
        #logInfo("🎬 프로덕션 에러 처리 및 복구 패턴 데모 시작")

        let demo = ProductionErrorHandlingDemo()
        await demo.demonstrateErrorHandling()

        #logInfo("🎉 프로덕션 에러 처리 및 복구 패턴 데모 완료")
    }
}