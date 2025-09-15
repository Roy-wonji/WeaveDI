//
//  SafeInjectionExamples.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

//import Foundation
import LogMacro
//
//// MARK: - Safe Injection Examples
//
///// 안전한 의존성 주입 예제
//public struct SafeInjectionExamples {
//
//    // MARK: - Basic Safe Injection
//
//    /// 기본 안전한 의존성 주입 예제
//    public static func basicSafeInjectionExample() async {
//        #logDebug("🛡️ Safe Injection Example")
//
//        // 서비스 등록
//        UnifiedDI.register(UserServiceProtocol.self) { UserServiceImpl() }
//
//        // 안전한 의존성 주입 사용
//        var viewController = SafeUserViewController()
//        await viewController.loadUser()
//    }
//
//    /// 순환 의존성 탐지 예제
//    public static func circularDependencyDetectionExample() async {
//        #logInfo("🔄 Circular Dependency Detection Example")
//
//        // 순환 의존성 활성화
//        CircularDependencyDetector.shared.setDetectionEnabled(true)
//
//        // 순환 의존성이 있는 서비스 등록 시도
//        do {
//            try await registerCircularDependencies()
//        } catch let error as SafeDIError {
//            #logDebug("탐지된 순환 의존성: \(error.debugDescription)")
//        } catch {
//            #logDebug("알 수 없는 에러: \(error)")
//        }
//    }
//
//    /// 의존성 그래프 시각화 예제
//    public static func dependencyGraphVisualizationExample() {
//        #logInfo("📊 Dependency Graph Visualization Example")
//
//        // 의존성 등록
//        registerSampleDependencies()
//
//        // 텍스트 기반 의존성 트리 출력
//        let tree = DependencyGraphVisualizer.shared.generateDependencyTree(UserServiceProtocol.self)
//        #logDebug(tree)
//
//        // 그래프 통계
//        let statistics = CircularDependencyDetector.shared.getGraphStatistics()
//        #logDebug(statistics.summary)
//
//        // DOT 그래프 생성
//        let dotGraph = DependencyGraphVisualizer.shared.generateDOTGraph(
//            title: "Sample Dependency Graph"
//        )
//        #logDebug("DOT Graph:")
//        #logDebug(dotGraph)
//    }
//
//    /// 에러 복구 전략 예제
//    public static func errorRecoveryExample() async {
//        #logDebug("🔧 Error Recovery Strategy Example")
//
//        // 의존성 미등록 상태에서 복구 전략 사용
//        var example = ErrorRecoveryExample()
//        await example.demonstrateRecoveryStrategies()
//    }
//
//    /// 마이그레이션 예제
//    public static func migrationExample() {
//        #logInfo("🔄 Migration from fatalError to Safe Injection Example")
//
//        var migrationExample = MigrationExample()
//        migrationExample.demonstrateMigration()
//    }
//
//    // MARK: - Private Helpers
//
//    private static func registerCircularDependencies() async throws {
//        // A → B → C → A 순환 의존성 생성
//        CircularDependencyDetector.shared.recordDependency(from: "ServiceA", to: "ServiceB")
//        CircularDependencyDetector.shared.recordDependency(from: "ServiceB", to: "ServiceC")
//        CircularDependencyDetector.shared.recordDependency(from: "ServiceC", to: "ServiceA")
//
//        // 순환 의존성 탐지
//        let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()
//        if !cycles.isEmpty {
//            throw SafeDIError.circularDependency(path: cycles.first?.path ?? [])
//        }
//    }
//
//    private static func registerSampleDependencies() {
//        UnifiedDI.register(UserServiceProtocol.self) { UserServiceImpl() }
//        UnifiedDI.register(NetworkServiceProtocol.self) { URLSessionNetworkService() }
//        UnifiedDI.register(LoggerProtocol.self) { ConsoleLoggerService() }
//
//        // 의존성 관계 기록
//        CircularDependencyDetector.shared.recordDependency(
//            from: UserServiceProtocol.self,
//            to: NetworkServiceProtocol.self
//        )
//        CircularDependencyDetector.shared.recordDependency(
//            from: UserServiceProtocol.self,
//            to: LoggerProtocol.self
//        )
//    }
//}
//
//// MARK: - Example Classes
//
///// 안전한 의존성 주입을 사용하는 뷰 컨트롤러
//public class SafeUserViewController {
//
//    @SafeInject var userService: UserServiceProtocol?
//    @SafeInject var logger: LoggerProtocol?
//
//    public init() {}
//
//    public func loadUser() async {
//        // 안전한 방식으로 의존성 사용
//        let userServiceResult = userService
//        let loggerResult = logger
//
//        userServiceResult.onSuccess { service in
//            #logInfo("✅ UserService 로드 성공")
//            // 서비스 사용
//        }
//
//        userServiceResult.onFailure { error in
//            #logError("❌ UserService 로드 실패: \(error.description)")
//            // 에러 처리 또는 대체 로직
//        }
//
//        loggerResult.onSuccess { logger in
//            logger.info("사용자 로딩 시작")
//        }
//    }
//}
//
///// 에러 복구 전략 데모
//public struct ErrorRecoveryExample {
//
//    @SafeInject var userService: UserServiceProtocol?
//
//    public init() {}
//
//    public mutating func demonstrateRecoveryStrategies() async {
//        #logDebug("🔧 복구 전략 데모")
//
//        // 전략 1: 기본값 사용
//        let serviceWithDefault = userService.getValue(strategy: .useDefault(MockUserService()))
//        #logDebug("기본값 전략: \(serviceWithDefault != nil ? "성공" : "실패")")
//
//        // 전략 2: 재시도
//        let serviceWithRetry = userService.getValue(strategy: .retry(maxAttempts: 3))
//        #logDebug("재시도 전략: \(serviceWithRetry != nil ? "성공" : "실패")")
//
//        // 전략 3: Fallback 클로저
//        let serviceWithFallback = userService.getValue(strategy: .fallback {
//            #logInfo("Fallback 서비스 생성")
//            return MockUserService()
//        })
//        #logDebug("Fallback 전략: \(serviceWithFallback != nil ? "성공" : "실패")")
//
//        // 전략 4: 무시
//        let serviceIgnored = userService.getValue(strategy: .ignore)
//        #logDebug("무시 전략: \(serviceIgnored != nil ? "성공" : "실패")")
//    }
//}
//
///// 마이그레이션 예제
//public struct MigrationExample {
//
//    @SafeInject var userService: UserServiceProtocol?
//
//    public init() {}
//
//    public mutating func demonstrateMigration() {
//        #logInfo("🔄 마이그레이션 데모")
//
//        // 기존 방식 (안전하지 않음)
//        let oldStyleService = SafeInjectionMigration.migrateInject(userService)
//        if let service = oldStyleService {
//            #logInfo("✅ 기존 방식으로 서비스 로드 성공")
//        } else {
//            #logError("❌ 기존 방식으로 서비스 로드 실패")
//        }
//
//        // 새로운 방식 (로깅과 fallback 포함)
//        let newStyleService = SafeInjectionMigration.migrateInjectWithLogging(
//            userService,
//            fallback: MockUserService()
//        )
//        if let service = newStyleService {
//            #logInfo("✅ 새로운 방식으로 서비스 로드 성공")
//        } else {
//            #logError("❌ 새로운 방식으로 서비스 로드 실패")
//        }
//
//        // Result 스타일 사용
//        userService
//            .map { service in
//                #logDebug("서비스 변환: \(type(of: service))")
//                return service
//            }
//            .onSuccess { service in
//                #logInfo("✅ 서비스 사용 준비 완료")
//            }
//            .onFailure { error in
//                #logError("❌ 서비스 로드 에러: \(error)")
//            }
//    }
//}
//
//// MARK: - Mock Services
//
//public class MockUserService: UserServiceProtocol {
//    public func getCurrentUser() async throws -> String {
//        return "Mock User"
//    }
//
//    public func handleAsyncTask() async {
//        #logDebug("Mock async task completed")
//    }
//}
//
//// MARK: - Demo Runner
//
//public struct SafeInjectionDemoRunner {
//
//    public static func runAllExamples() async {
//        #logInfo("🚀 Safe Injection Examples 시작\n")
//
//        await SafeInjectionExamples.basicSafeInjectionExample()
//        print()
//
//        await SafeInjectionExamples.circularDependencyDetectionExample()
//        print()
//
//        SafeInjectionExamples.dependencyGraphVisualizationExample()
//        print()
//
//        await SafeInjectionExamples.errorRecoveryExample()
//        print()
//
//        SafeInjectionExamples.migrationExample()
//        print()
//
//        #logInfo("🎉 모든 Safe Injection Examples 완료")
//    }
//}
