import Foundation
import DiContainer
import LogMacro

// MARK: - Environment-based Configuration System

/// 환경별 Configuration 시스템
/// Development, Staging, Production에 따라 다른 서비스를 주입

// MARK: - Environment Configuration

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

    var name: String {
        rawValue.capitalized
    }
}

// MARK: - Environment-specific Services

/// 환경별 API 서비스
protocol APIService: Sendable {
    var baseURL: String { get }
    var timeout: TimeInterval { get }
    var logLevel: LogLevel { get }
    func makeRequest(endpoint: String) async throws -> String
}

enum LogLevel: String, Sendable {
    case verbose = "verbose"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case none = "none"
}

/// Development 환경용 API 서비스
final class DevelopmentAPIService: APIService, @unchecked Sendable {
    let baseURL = "https://dev-api.example.com"
    let timeout: TimeInterval = 30.0
    let logLevel = LogLevel.verbose

    func makeRequest(endpoint: String) async throws -> String {
        #logInfo("🔧 [Dev API] 요청: \(baseURL)\(endpoint)")

        // Development에서는 실제 네트워크 대신 Mock 응답
        await Task.sleep(nanoseconds: 100_000_000) // 0.1초 지연

        let response = """
        {
            "data": "Development Mock Response",
            "endpoint": "\(endpoint)",
            "timestamp": "\(Date())",
            "environment": "development"
        }
        """

        #logInfo("📥 [Dev API] 응답 수신: \(response.count)자")
        return response
    }
}

/// Staging 환경용 API 서비스
final class StagingAPIService: APIService, @unchecked Sendable {
    let baseURL = "https://staging-api.example.com"
    let timeout: TimeInterval = 15.0
    let logLevel = LogLevel.info

    func makeRequest(endpoint: String) async throws -> String {
        #logInfo("🔄 [Staging API] 요청: \(baseURL)\(endpoint)")

        // Staging에서는 실제 서버와 유사하게 동작
        await Task.sleep(nanoseconds: 500_000_000) // 0.5초 지연

        if endpoint.contains("error") {
            throw APIError.stagingError("Staging 테스트 에러")
        }

        let response = """
        {
            "data": "Staging Response",
            "endpoint": "\(endpoint)",
            "server": "staging-server-01",
            "environment": "staging"
        }
        """

        #logInfo("📥 [Staging API] 응답 수신")
        return response
    }
}

/// Production 환경용 API 서비스
final class ProductionAPIService: APIService, @unchecked Sendable {
    let baseURL = "https://api.example.com"
    let timeout: TimeInterval = 10.0
    let logLevel = LogLevel.error

    private let networkQueue = DispatchQueue(label: "ProductionAPI.network", qos: .userInitiated)

    func makeRequest(endpoint: String) async throws -> String {
        // Production에서는 최소한의 로그만 출력

        return try await withCheckedThrowingContinuation { continuation in
            networkQueue.async {
                // 실제 네트워크 요청 시뮬레이션
                Thread.sleep(forTimeInterval: 0.8) // 0.8초 지연

                if endpoint.contains("timeout") {
                    continuation.resume(throwing: APIError.timeout)
                    return
                }

                if endpoint.contains("unauthorized") {
                    continuation.resume(throwing: APIError.unauthorized)
                    return
                }

                let response = """
                {
                    "data": "Production Response",
                    "endpoint": "\(endpoint)",
                    "status": "success"
                }
                """

                continuation.resume(returning: response)
            }
        }
    }
}

// MARK: - Environment-specific Analytics

protocol AnalyticsService: Sendable {
    func track(event: String, properties: [String: Any]) async
    func setUserProperty(key: String, value: Any) async
}

final class DevelopmentAnalyticsService: AnalyticsService {
    func track(event: String, properties: [String: Any]) async {
        #logInfo("📊 [Dev Analytics] 이벤트: \(event)")
        #logInfo("📊 [Dev Analytics] 속성: \(properties)")
    }

    func setUserProperty(key: String, value: Any) async {
        #logInfo("👤 [Dev Analytics] 사용자 속성 설정: \(key) = \(value)")
    }
}

final class StagingAnalyticsService: AnalyticsService {
    private let events = DispatchSemaphore(value: 1)
    private var eventBuffer: [(String, [String: Any])] = []

    func track(event: String, properties: [String: Any]) async {
        events.wait()
        eventBuffer.append((event, properties))
        events.signal()

        #logInfo("📊 [Staging Analytics] 이벤트 버퍼에 추가: \(event)")

        // 10개씩 배치 전송
        if eventBuffer.count >= 10 {
            await flushEvents()
        }
    }

    func setUserProperty(key: String, value: Any) async {
        #logInfo("👤 [Staging Analytics] 사용자 속성 설정: \(key)")
    }

    private func flushEvents() async {
        events.wait()
        let eventsToSend = eventBuffer
        eventBuffer.removeAll()
        events.signal()

        #logInfo("📤 [Staging Analytics] \(eventsToSend.count)개 이벤트 전송")
    }
}

final class ProductionAnalyticsService: AnalyticsService {
    private let networkManager = URLSession.shared

    func track(event: String, properties: [String: Any]) async {
        // Production에서는 실제 분석 서비스로 전송
        // (실제 구현에서는 Firebase, Mixpanel 등 사용)

        do {
            let data = try JSONSerialization.data(withJSONObject: [
                "event": event,
                "properties": properties,
                "timestamp": Date().timeIntervalSince1970
            ])

            // 실제 전송 로직 (여기서는 시뮬레이션)
            await Task.sleep(nanoseconds: 200_000_000) // 0.2초

        } catch {
            // Production에서는 에러를 조용히 처리
        }
    }

    func setUserProperty(key: String, value: Any) async {
        // 사용자 속성 설정 (조용히 처리)
    }
}

// MARK: - Environment Configuration Manager

/// 환경별 의존성을 관리하는 매니저
final class EnvironmentConfigurationManager: @unchecked Sendable {
    static let shared = EnvironmentConfigurationManager()

    private let currentEnvironment: AppEnvironment

    private init() {
        self.currentEnvironment = AppEnvironment.current
        #logInfo("🌍 [Config] 현재 환경: \(currentEnvironment.name)")
    }

    /// 환경별 의존성을 컨테이너에 등록합니다
    func registerEnvironmentDependencies(to container: DIContainer) async {
        #logInfo("⚙️ [Config] 환경별 의존성 등록 시작: \(currentEnvironment.name)")

        await registerAPIService(to: container)
        await registerAnalyticsService(to: container)
        await registerDatabaseService(to: container)
        await registerCacheService(to: container)

        #logInfo("✅ [Config] 환경별 의존성 등록 완료")
    }

    private func registerAPIService(to container: DIContainer) async {
        switch currentEnvironment {
        case .development:
            container.register(APIService.self) {
                DevelopmentAPIService()
            }
            #logInfo("🔧 [Config] Development API 서비스 등록")

        case .staging:
            container.register(APIService.self) {
                StagingAPIService()
            }
            #logInfo("🔄 [Config] Staging API 서비스 등록")

        case .production:
            container.register(APIService.self) {
                ProductionAPIService()
            }
            #logInfo("🚀 [Config] Production API 서비스 등록")
        }
    }

    private func registerAnalyticsService(to container: DIContainer) async {
        switch currentEnvironment {
        case .development:
            container.register(AnalyticsService.self) {
                DevelopmentAnalyticsService()
            }

        case .staging:
            container.register(AnalyticsService.self) {
                StagingAnalyticsService()
            }

        case .production:
            container.register(AnalyticsService.self) {
                ProductionAnalyticsService()
            }
        }
    }

    private func registerDatabaseService(to container: DIContainer) async {
        // 환경별 데이터베이스 설정
        switch currentEnvironment {
        case .development:
            container.register("DatabaseURL") { "sqlite://dev.db" }
            container.register("DatabaseConnectionPool") { 5 }

        case .staging:
            container.register("DatabaseURL") { "postgresql://staging-db:5432/app" }
            container.register("DatabaseConnectionPool") { 20 }

        case .production:
            container.register("DatabaseURL") { "postgresql://prod-db:5432/app" }
            container.register("DatabaseConnectionPool") { 50 }
        }
    }

    private func registerCacheService(to container: DIContainer) async {
        // 환경별 캐시 설정
        switch currentEnvironment {
        case .development:
            container.register("CacheSize") { 10 * 1024 * 1024 } // 10MB
            container.register("CacheTTL") { TimeInterval(300) } // 5분

        case .staging:
            container.register("CacheSize") { 100 * 1024 * 1024 } // 100MB
            container.register("CacheTTL") { TimeInterval(1800) } // 30분

        case .production:
            container.register("CacheSize") { 500 * 1024 * 1024 } // 500MB
            container.register("CacheTTL") { TimeInterval(3600) } // 1시간
        }
    }
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case timeout
    case unauthorized
    case stagingError(String)

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "요청 시간 초과"
        case .unauthorized:
            return "인증되지 않은 요청"
        case .stagingError(let message):
            return "Staging 오류: \(message)"
        }
    }
}

// MARK: - Usage Example

/// 환경별 Configuration 사용 예제
final class EnvironmentConfigurationExample {
    @Inject private var apiService: APIService
    @Inject private var analyticsService: AnalyticsService

    func demonstrateEnvironmentConfiguration() async {
        #logInfo("🌍 [Example] 환경별 설정 예제 시작")

        // 환경별 의존성 등록
        await EnvironmentConfigurationManager.shared.registerEnvironmentDependencies(
            to: DIContainer.shared
        )

        // API 서비스 사용
        do {
            let response = try await apiService.makeRequest(endpoint: "/users")
            #logInfo("📡 [Example] API 응답 수신: \(response.count)자")
        } catch {
            #logError("❌ [Example] API 요청 실패: \(error)")
        }

        // Analytics 서비스 사용
        await analyticsService.track(event: "app_launched", properties: [
            "environment": AppEnvironment.current.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ])

        await analyticsService.setUserProperty(key: "user_type", value: "premium")

        #logInfo("✅ [Example] 환경별 설정 예제 완료")
    }

    /// 환경별 설정값 확인
    func checkEnvironmentSettings() {
        #logInfo("⚙️ [Example] 환경별 설정값 확인")
        #logInfo("  • 현재 환경: \(AppEnvironment.current.name)")
        #logInfo("  • API URL: \(apiService.baseURL)")
        #logInfo("  • 타임아웃: \(apiService.timeout)초")
        #logInfo("  • 로그 레벨: \(apiService.logLevel.rawValue)")

        // 의존성 주입된 설정값들 확인
        if let dbUrl = UnifiedDI.resolve(String.self, name: "DatabaseURL") {
            #logInfo("  • 데이터베이스 URL: \(dbUrl)")
        }

        if let cacheSize = UnifiedDI.resolve(Int.self, name: "CacheSize") {
            #logInfo("  • 캐시 크기: \(cacheSize / 1024 / 1024)MB")
        }
    }
}