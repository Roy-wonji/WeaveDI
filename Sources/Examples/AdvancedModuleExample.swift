//
//  AdvancedModuleExample.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - Example Services (Namespace: AdvancedExample)

//public enum AdvancedExample {
//    protocol DatabaseService {
//        func connect() async throws
//        func isConnected() -> Bool
//    }
//
//    protocol LoggingService {
//        func log(_ message: String)
//        func setLevel(_ level: LogLevel)
//    }
//
//    protocol NetworkService {
//        func isReachable() -> Bool
//    }
//
//    protocol AnalyticsServiceProtocol {
//        func track(_ event: String)
//        func isEnabled() -> Bool
//    }
//
//    enum LogLevel {
//        case debug, info, warning, error
//    }
//}
//
//// MARK: - Mock Implementations (using AdvancedExample namespace)
//
//struct MockDatabaseService: AdvancedExample.DatabaseService {
//    private var connected = false
//
//    func connect() async throws {
//        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
//        // connected = true  // Note: This would be mutating, so we'll just simulate
//    }
//
//    func isConnected() -> Bool {
//        return true // Assume connected for demo
//    }
//}
//
//struct ConsoleLoggingService: AdvancedExample.LoggingService {
//    private var currentLevel: AdvancedExample.LogLevel = .info
//
//    func log(_ message: String) {
//        print("[LOG] \(message)")
//    }
//
//    func setLevel(_ level: AdvancedExample.LogLevel) {
//        // currentLevel = level // Note: This would be mutating
//        print("[LOG] Setting level to \(level)")
//    }
//}
//
//struct MockNetworkService: AdvancedExample.NetworkService {
//    func isReachable() -> Bool {
//        return true // Assume network is available
//    }
//}
//
//struct GoogleAnalyticsService: AdvancedExample.AnalyticsServiceProtocol {
//    func track(_ event: String) {
//        print("[Analytics] Tracking: \(event)")
//    }
//
//    func isEnabled() -> Bool {
//        return ProcessInfo.processInfo.environment["ANALYTICS_ENABLED"] == "true"
//    }
//}
//
//// MARK: - Advanced Module Usage Examples
//
///// 고급 모듈 시스템 사용 예시
//public final class AdvancedModuleExample {
//
//    /// Example 1: 기본 조건부 모듈
//    public static func createBasicConditionalModules() -> [AdvancedModule] {
//        // 데이터베이스 모듈 (항상 등록)
//        let databaseModule = Module(DatabaseService.self) {
//            MockDatabaseService()
//        }.asAdvanced(
//            identifier: "database",
//            dependencies: []
//        )
//
//        // 로깅 모듈 (데이터베이스 이후 등록)
//        let loggingModule = Module(LoggingService.self) {
//            ConsoleLoggingService()
//        }.asAdvanced(
//            identifier: "logging",
//            dependencies: ["database"]
//        )
//
//        // 네트워크 모듈 (디버그 빌드에서만)
//        let networkModule = ConditionalModule.debugOnly(
//            identifier: "network",
//            dependencies: ["logging"],
//            module: Module(NetworkService.self) {
//                MockNetworkService()
//            }
//        )
//
//        // 분석 모듈 (환경 변수 기반)
//        let analyticsModule = ConditionalModule.fromEnvironment(
//            identifier: "analytics",
//            dependencies: ["network"],
//            envKey: "ANALYTICS_ENABLED",
//            expectedValue: "true",
//            module: Module(AnalyticsService.self) {
//                GoogleAnalyticsService()
//            }
//        )
//
//        return [databaseModule, loggingModule, networkModule, analyticsModule]
//    }
//
//    /// Example 2: 라이프사이클 훅이 포함된 모듈
//    public static func createModuleWithHooks() -> ConditionalModule {
//        let databaseModule = Module(DatabaseService.self) {
//            MockDatabaseService()
//        }
//
//        return ConditionalModule(
//            identifier: "database-with-hooks",
//            dependencies: [],
//            condition: { true },
//            module: databaseModule,
//            beforeRegister: {
//                print("🔧 [Lifecycle] Database module 등록 전 설정 중...")
//                // 설정 파일 로드, 환경 변수 확인 등
//            },
//            afterRegister: {
//                print("✅ [Lifecycle] Database module 등록 완료")
//                // 헬스 체크, 로깅 등
//            },
//            validator: {
//                // 실제 DB 연결 테스트
//                guard let dbService: DatabaseService = DependencyContainer.live.resolve(DatabaseService.self) else {
//                    throw ModuleSystemError.validationFailed("database-with-hooks",
//                                                           ValidationError.serviceNotResolved)
//                }
//
//                if !dbService.isConnected() {
//                    throw ModuleSystemError.validationFailed("database-with-hooks",
//                                                           ValidationError.serviceNotReady)
//                }
//
//                print("✅ [Validation] Database connection verified")
//            }
//        )
//    }
//
//    /// Example 3: 모듈 그룹 생성
//    public static func createModuleGroups() -> ModuleGroup {
//        let coreModules = createBasicConditionalModules()
//        let dbWithHooks = createModuleWithHooks()
//
//        return ModuleGroup(
//            identifier: "application-modules",
//            dependencies: [],
//            condition: { true },
//            modules: coreModules + [dbWithHooks],
//            parallelRegistration: false // 의존성 순서 고려
//        )
//    }
//
//    /// Example 4: DSL 스타일 모듈 등록
//    @MainActor
//    public static func registerWithDSL() async throws {
//        try await ModuleRegistry.shared.registerModules {
//            // 핵심 서비스들
//            Module(DatabaseService.self) {
//                MockDatabaseService()
//            }.asAdvanced(identifier: "core-database")
//
//            Module(LoggingService.self) {
//                ConsoleLoggingService()
//            }.asAdvanced(
//                identifier: "core-logging",
//                dependencies: ["core-database"]
//            )
//
//            // 조건부 서비스들
//            ConditionalModule.debugOnly(
//                identifier: "debug-network",
//                dependencies: ["core-logging"],
//                module: Module(NetworkService.self) {
//                    MockNetworkService()
//                }
//            )
//
//            ConditionalModule.fromUserDefault(
//                identifier: "user-analytics",
//                dependencies: ["debug-network"],
//                key: "analytics_enabled",
//                module: Module(AnalyticsService.self) {
//                    GoogleAnalyticsService()
//                }
//            )
//        }
//    }
//
//    /// Example 5: 모듈 상태 모니터링
//    @MainActor
//    public static func monitorModuleStatus() {
//        let registry = ModuleRegistry.shared
//
//        // 등록된 모든 모듈 상태 확인
//        for (identifier, _) in registry.registeredModules {
//            if let status = registry.status(for: identifier) {
//                switch status {
//                case .registering:
//                    print("⏳ Module \(identifier) is registering...")
//                case .registered:
//                    print("✅ Module \(identifier) is ready")
//                case .failed(let error):
//                    print("❌ Module \(identifier) failed: \(error)")
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Custom Validation Errors
//
//enum ValidationError: Error, LocalizedError {
//    case serviceNotResolved
//    case serviceNotReady
//    case configurationMissing
//
//    var errorDescription: String? {
//        switch self {
//        case .serviceNotResolved:
//            return "서비스가 해결되지 않았습니다"
//        case .serviceNotReady:
//            return "서비스가 준비되지 않았습니다"
//        case .configurationMissing:
//            return "필수 설정이 누락되었습니다"
//        }
//    }
//}
//
//// MARK: - Integration Example
//
///// 실제 앱에서 고급 모듈 시스템을 사용하는 방법
//public final class AppModuleBootstrap {
//
//    @MainActor
//    public static func bootstrap() async throws {
//        print("🚀 [Bootstrap] Starting advanced module system...")
//
//        // 1. 환경별 모듈 등록
//        if isProduction() {
//            try await registerProductionModules()
//        } else {
//            try await registerDevelopmentModules()
//        }
//
//        // 2. 모듈 상태 확인
//        AdvancedModuleExample.monitorModuleStatus()
//
//        // 3. 앱 시작 준비 완료
//        print("✅ [Bootstrap] All modules loaded successfully!")
//    }
//
//    @MainActor
//    private static func registerProductionModules() async throws {
//        try await ModuleRegistry.shared.registerModules {
//            // 프로덕션용 서비스들
//            ConditionalModule.fromEnvironment(
//                identifier: "prod-database",
//                envKey: "DATABASE_URL",
//                expectedValue: ProcessInfo.processInfo.environment["DATABASE_URL"] ?? "",
//                module: Module(DatabaseService.self) {
//                    MockDatabaseService() // 실제로는 RealDatabaseService()
//                }
//            )
//
//            Module(LoggingService.self) {
//                ConsoleLoggingService() // 실제로는 RemoteLoggingService()
//            }.asAdvanced(
//                identifier: "prod-logging",
//                dependencies: ["prod-database"]
//            )
//        }
//    }
//
//    @MainActor
//    private static func registerDevelopmentModules() async throws {
//        try await AdvancedModuleExample.registerWithDSL()
//    }
//
//    private static func isProduction() -> Bool {
//        return ProcessInfo.processInfo.environment["ENVIRONMENT"] == "production"
//    }
//}
