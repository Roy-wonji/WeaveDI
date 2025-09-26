import Foundation
import DiContainer
import LogMacro

// MARK: - 환경별 설정 시스템

/// 개발, 스테이징, 프로덕션 환경에 따라 다른 서비스를 주입하는
/// 고급 환경별 구성 시스템을 구현합니다.

// MARK: - 환경 정의

enum AppEnvironment: String, Sendable, CaseIterable {
    case development = "development"
    case staging = "staging"
    case production = "production"

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }

    var displayName: String {
        switch self {
        case .development: return "개발"
        case .staging: return "스테이징"
        case .production: return "프로덕션"
        }
    }
}

// MARK: - 환경별 구성

struct EnvironmentConfig: Sendable {
    let apiBaseURL: String
    let timeoutInterval: TimeInterval
    let logLevel: LogLevel
    let enableAnalytics: Bool
    let enableCrashReporting: Bool
    let maxRetryCount: Int
    let cacheExpirationTime: TimeInterval

    static func config(for environment: AppEnvironment) -> EnvironmentConfig {
        switch environment {
        case .development:
            return EnvironmentConfig(
                apiBaseURL: "https://api-dev.example.com",
                timeoutInterval: 30.0,
                logLevel: .debug,
                enableAnalytics: false,
                enableCrashReporting: false,
                maxRetryCount: 1,
                cacheExpirationTime: 60.0 // 1분
            )

        case .staging:
            return EnvironmentConfig(
                apiBaseURL: "https://api-staging.example.com",
                timeoutInterval: 20.0,
                logLevel: .info,
                enableAnalytics: true,
                enableCrashReporting: true,
                maxRetryCount: 2,
                cacheExpirationTime: 300.0 // 5분
            )

        case .production:
            return EnvironmentConfig(
                apiBaseURL: "https://api.example.com",
                timeoutInterval: 15.0,
                logLevel: .warning,
                enableAnalytics: true,
                enableCrashReporting: true,
                maxRetryCount: 3,
                cacheExpirationTime: 1800.0 // 30분
            )
        }
    }
}

enum LogLevel: String, Sendable, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

// MARK: - 환경별 서비스 구현

// MARK: API Service

protocol APIService: Sendable {
    var baseURL: String { get }
    var timeout: TimeInterval { get }
    func makeRequest<T: Codable>(endpoint: String, responseType: T.Type) async throws -> T
    func uploadFile(endpoint: String, data: Data) async throws -> String
}

final class DevelopmentAPIService: APIService {
    let baseURL = "https://api-dev.example.com"
    let timeout: TimeInterval = 30.0

    func makeRequest<T: Codable>(endpoint: String, responseType: T.Type) async throws -> T {
        #logInfo("🔍 [Dev API] 요청: \(baseURL)\(endpoint)")
        // 개발 환경용 Mock 응답 또는 실제 API 호출
        // 더 자세한 로깅과 디버그 정보 포함

        try await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기 (시뮬레이션)

        // Mock 응답 반환 (실제로는 네트워크 호출)
        throw APIServiceError.notImplemented("개발 환경에서는 Mock 응답을 반환합니다")
    }

    func uploadFile(endpoint: String, data: Data) async throws -> String {
        #logInfo("🔍 [Dev API] 파일 업로드: \(data.count) bytes")
        return "dev-upload-\(UUID().uuidString)"
    }
}

final class StagingAPIService: APIService {
    let baseURL = "https://api-staging.example.com"
    let timeout: TimeInterval = 20.0

    func makeRequest<T: Codable>(endpoint: String, responseType: T.Type) async throws -> T {
        #logInfo("ℹ️ [Staging API] 요청: \(baseURL)\(endpoint)")
        // 스테이징 환경 - 프로덕션과 유사하지만 더 관대한 타임아웃

        try await Task.sleep(nanoseconds: 200_000_000) // 0.2초 대기
        throw APIServiceError.notImplemented("스테이징 환경 API 호출")
    }

    func uploadFile(endpoint: String, data: Data) async throws -> String {
        #logInfo("ℹ️ [Staging API] 파일 업로드: \(data.count) bytes")
        return "staging-upload-\(UUID().uuidString)"
    }
}

final class ProductionAPIService: APIService {
    let baseURL = "https://api.example.com"
    let timeout: TimeInterval = 15.0

    func makeRequest<T: Codable>(endpoint: String, responseType: T.Type) async throws -> T {
        #logInfo("ℹ️ [Prod API] 요청: \(baseURL)\(endpoint)")
        // 프로덕션 환경 - 최소한의 로깅, 최적화된 성능

        try await Task.sleep(nanoseconds: 50_000_000) // 0.05초 대기
        throw APIServiceError.notImplemented("프로덕션 환경 API 호출")
    }

    func uploadFile(endpoint: String, data: Data) async throws -> String {
        return "prod-upload-\(UUID().uuidString)"
    }
}

enum APIServiceError: Error {
    case notImplemented(String)
    case networkError(Error)
    case invalidResponse
    case timeout
}

// MARK: Analytics Service

protocol AnalyticsService: Sendable {
    func trackEvent(name: String, parameters: [String: Any])
    func trackScreen(name: String)
    func setUserProperty(key: String, value: String)
}

final class NoOpAnalyticsService: AnalyticsService {
    func trackEvent(name: String, parameters: [String: Any]) {
        #logInfo("🔍 [Dev Analytics] 이벤트 추적 (무시됨): \(name)")
    }

    func trackScreen(name: String) {
        #logInfo("🔍 [Dev Analytics] 화면 추적 (무시됨): \(name)")
    }

    func setUserProperty(key: String, value: String) {
        #logInfo("🔍 [Dev Analytics] 사용자 속성 (무시됨): \(key)=\(value)")
    }
}

final class ProductionAnalyticsService: AnalyticsService {
    func trackEvent(name: String, parameters: [String: Any]) {
        #logInfo("📊 [Prod Analytics] 이벤트 추적: \(name)")
        // 실제 분석 도구로 전송
    }

    func trackScreen(name: String) {
        #logInfo("📊 [Prod Analytics] 화면 추적: \(name)")
        // 실제 분석 도구로 전송
    }

    func setUserProperty(key: String, value: String) {
        #logInfo("📊 [Prod Analytics] 사용자 속성: \(key)=\(value)")
        // 실제 분석 도구로 전송
    }
}

// MARK: Logging Service

protocol LoggingService: Sendable {
    func log(level: LogLevel, message: String, file: String, function: String, line: Int)
}

final class ConsoleLoggingService: LoggingService {
    private let minimumLevel: LogLevel

    init(minimumLevel: LogLevel) {
        self.minimumLevel = minimumLevel
    }

    func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        guard shouldLog(level: level) else { return }

        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())

        print("\(level.emoji) [\(timestamp)] \(fileName):\(line) \(function) - \(message)")
    }

    private func shouldLog(level: LogLevel) -> Bool {
        let levels: [LogLevel] = [.debug, .info, .warning, .error]
        guard let currentIndex = levels.firstIndex(of: minimumLevel),
              let logIndex = levels.firstIndex(of: level) else {
            return false
        }
        return logIndex >= currentIndex
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: Cache Service

protocol CacheService: Sendable {
    func set<T: Codable>(key: String, value: T, expiration: TimeInterval?) async
    func get<T: Codable>(key: String, type: T.Type) async -> T?
    func remove(key: String) async
    func clear() async
}

final class InMemoryCacheService: CacheService {
    private actor CacheStorage {
        private var storage: [String: CacheItem] = [:]

        func set(key: String, item: CacheItem) {
            storage[key] = item
        }

        func get(key: String) -> CacheItem? {
            guard let item = storage[key] else { return nil }

            // 만료 확인
            if let expiration = item.expiration, Date() > expiration {
                storage.removeValue(forKey: key)
                return nil
            }

            return item
        }

        func remove(key: String) {
            storage.removeValue(forKey: key)
        }

        func clear() {
            storage.removeAll()
        }
    }

    private struct CacheItem {
        let data: Data
        let expiration: Date?
    }

    private let storage = CacheStorage()

    func set<T: Codable>(key: String, value: T, expiration: TimeInterval?) async {
        do {
            let data = try JSONEncoder().encode(value)
            let expirationDate = expiration.map { Date().addingTimeInterval($0) }
            let item = CacheItem(data: data, expiration: expirationDate)

            await storage.set(key: key, item: item)
            #logInfo("💾 캐시 저장: \(key) (만료: \(expirationDate?.description ?? "없음"))")
        } catch {
            #logError("❌ 캐시 저장 실패: \(key) - \(error)")
        }
    }

    func get<T: Codable>(key: String, type: T.Type) async -> T? {
        guard let item = await storage.get(key: key) else {
            #logInfo("💾 캐시 미스: \(key)")
            return nil
        }

        do {
            let value = try JSONDecoder().decode(type, from: item.data)
            #logInfo("💾 캐시 히트: \(key)")
            return value
        } catch {
            #logError("❌ 캐시 역직렬화 실패: \(key) - \(error)")
            await storage.remove(key: key)
            return nil
        }
    }

    func remove(key: String) async {
        await storage.remove(key: key)
        #logInfo("💾 캐시 제거: \(key)")
    }

    func clear() async {
        await storage.clear()
        #logInfo("💾 캐시 전체 삭제")
    }
}

// MARK: - 환경별 DI 컨테이너 설정

extension DIContainer {
    /// 현재 환경에 맞는 서비스들을 등록합니다
    func registerEnvironmentSpecificServices() async {
        let environment = AppEnvironment.current
        let config = EnvironmentConfig.config(for: environment)

        #logInfo("🌍 환경별 서비스 등록: \(environment.displayName) 환경")

        // 환경 설정 등록
        registerSingleton(EnvironmentConfig.self) { config }

        // API 서비스 등록
        switch environment {
        case .development:
            registerSingleton(APIService.self) { DevelopmentAPIService() }
        case .staging:
            registerSingleton(APIService.self) { StagingAPIService() }
        case .production:
            registerSingleton(APIService.self) { ProductionAPIService() }
        }

        // Analytics 서비스 등록
        if config.enableAnalytics {
            registerSingleton(AnalyticsService.self) { ProductionAnalyticsService() }
        } else {
            registerSingleton(AnalyticsService.self) { NoOpAnalyticsService() }
        }

        // Logging 서비스 등록
        registerSingleton(LoggingService.self) {
            ConsoleLoggingService(minimumLevel: config.logLevel)
        }

        // Cache 서비스 등록
        registerSingleton(CacheService.self) { InMemoryCacheService() }

        #logInfo("✅ 환경별 서비스 등록 완료")
        #logInfo("📊 등록된 서비스:")
        #logInfo("   - API Base URL: \(config.apiBaseURL)")
        #logInfo("   - Log Level: \(config.logLevel.rawValue)")
        #logInfo("   - Analytics: \(config.enableAnalytics ? "활성화" : "비활성화")")
        #logInfo("   - Cache Expiration: \(config.cacheExpirationTime)초")
    }

    /// 환경별 설정을 동적으로 변경합니다 (테스트용)
    func switchEnvironment(to environment: AppEnvironment) async {
        #logInfo("🔄 환경 전환: \(environment.displayName)")

        // 기존 등록 제거
        removeRegistration(for: APIService.self)
        removeRegistration(for: AnalyticsService.self)
        removeRegistration(for: LoggingService.self)

        // 새로운 환경 설정으로 재등록
        let config = EnvironmentConfig.config(for: environment)

        switch environment {
        case .development:
            registerSingleton(APIService.self) { DevelopmentAPIService() }
            registerSingleton(AnalyticsService.self) { NoOpAnalyticsService() }
        case .staging, .production:
            registerSingleton(APIService.self) {
                environment == .staging ? StagingAPIService() : ProductionAPIService()
            }
            registerSingleton(AnalyticsService.self) { ProductionAnalyticsService() }
        }

        registerSingleton(LoggingService.self) {
            ConsoleLoggingService(minimumLevel: config.logLevel)
        }

        #logInfo("✅ 환경 전환 완료: \(environment.displayName)")
    }
}

// MARK: - 환경별 설정 사용 예제

final class EnvironmentAwareService {
    @Inject private var apiService: APIService
    @Inject private var analyticsService: AnalyticsService
    @Inject private var cacheService: CacheService
    @Inject private var config: EnvironmentConfig

    func performBusinessLogic() async {
        #logInfo("🚀 비즈니스 로직 실행")

        // 현재 환경에 맞는 서비스들 사용
        #logInfo("🌐 API 서비스: \(apiService.baseURL)")

        // Analytics 추적 (환경에 따라 실제 전송 여부 결정)
        analyticsService.trackEvent(name: "business_logic_executed", parameters: [:])

        // 캐시 사용 (환경별 만료 시간 적용)
        await cacheService.set(
            key: "business_data",
            value: ["timestamp": Date().timeIntervalSince1970],
            expiration: config.cacheExpirationTime
        )

        #logInfo("✅ 비즈니스 로직 완료 (환경: \(config.logLevel.rawValue))")
    }
}

// MARK: - 환경별 설정 데모

enum EnvironmentConfigExample {
    static func demonstrateEnvironmentConfiguration() async {
        #logInfo("🎬 환경별 설정 데모 시작")

        let container = DIContainer()

        // 현재 환경에 맞는 서비스 등록
        await container.registerEnvironmentSpecificServices()

        // 서비스 사용
        let service = EnvironmentAwareService()
        await service.performBusinessLogic()

        #logInfo("🔄 환경 전환 테스트")

        // 다른 환경으로 전환 (테스트용)
        await container.switchEnvironment(to: .production)
        await service.performBusinessLogic()

        await container.switchEnvironment(to: .development)
        await service.performBusinessLogic()

        #logInfo("🎉 환경별 설정 데모 완료")
    }
}