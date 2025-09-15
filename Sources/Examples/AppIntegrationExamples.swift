//
//  AppIntegrationExamples.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

//import Foundation
//import LogMacro
//
//// MARK: - App Integration Examples
//
///// 앱 통합 예제
//public struct AppIntegrationExamples {
//
//    // MARK: - AppDelegate Integration
//
//    /// AppDelegate에서 그래프 생성 (명시적 호출)
//    public static func setupDevelopmentGraphGeneration() {
//        #if DEBUG
//        #logInfo("💡 TIP: 의존성 그래프를 생성하려면 다음을 호출하세요:")
//        #logDebug("   AppIntegrationExamples.generateGraphsNow()")
//        #endif
//    }
//
//    /// 즉시 그래프 생성 (명시적 호출 전용)
//    public static func generateGraphsNow() {
//        #if DEBUG
//        Task {
//            #logInfo("🎨 의존성 그래프 생성 시작...")
//            try await GraphGenerationDemoRunner.quickCLI()
//        }
//        #endif
//    }
//
//    /// 조건부 그래프 생성 (환경변수 기반)
//    public static func conditionalGraphGeneration() {
//        // 환경변수로 제어
//        if ProcessInfo.processInfo.environment["GENERATE_DEPENDENCY_GRAPH"] == "true" {
//            Task {
//                try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기
//                #logInfo("🌳 환경변수 설정에 따른 그래프 생성...")
//                try AutoGraphGenerator.quickGenerate()
//            }
//        }
//    }
//
//    /// UserDefaults 기반 제어
//    public static func userDefaultsControlledGeneration() {
//        if UserDefaults.standard.bool(forKey: "EnableDependencyGraphGeneration") {
//            Task {
//                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5초 대기
//                #logInfo("⚙️ 설정에 따른 그래프 생성...")
//                try AutoGraphGenerator.quickGenerate()
//            }
//        }
//    }
//
//    // MARK: - SwiftUI Integration
//
//    /// SwiftUI App에서 사용
//    public static func swiftUIAppIntegration() -> some Sendable {
//        return {
//            #if DEBUG && !targetEnvironment(simulator)
//            Task {
//                try await Task.sleep(nanoseconds: 3_000_000_000) // 3초 대기
//                #logInfo("📱 SwiftUI 앱: 의존성 그래프 생성...")
//                try AutoGraphGenerator.quickGenerate()
//            }
//            #endif
//        }
//    }
//
//    // MARK: - UIKit Integration
//
//    /// UIKit 앱에서 사용 (AppDelegate 호출용)
//    public static func uikitAppDelegateSetup() {
//        #if DEBUG
//        // 개발 빌드에서만 실행
//        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
//            Task {
//                #logInfo("📱 UIKit 앱: 의존성 그래프 생성...")
//                do {
//                    try AutoGraphGenerator.quickGenerate()
//
//                    // 메인 스레드에서 알림 (선택사항)
//                    DispatchQueue.main.async {
//                        #logInfo("✅ 의존성 그래프가 생성되었습니다!")
//                        // 알림이나 로그 출력
//                    }
//                } catch {
//                    #logError("❌ 그래프 생성 실패: \(error)")
//                }
//            }
//        }
//        #endif
//    }
//
//    // MARK: - Scene-based Integration
//
//    /// Scene-based 앱에서 사용
//    public static func sceneBasedAppSetup() {
//        #if DEBUG
//        NotificationCenter.default.addObserver(
//            forName: UIScene.didActivateNotification,
//            object: nil,
//            queue: .main
//        ) { _ in
//            // Scene이 활성화된 후 그래프 생성
//            Task {
//                try await Task.sleep(nanoseconds: 1_000_000_000)
//                #logInfo("🏗️ Scene 활성화: 의존성 그래프 생성...")
//                try AutoGraphGenerator.quickGenerate()
//            }
//        }
//        #endif
//    }
//
//    // MARK: - Testing Integration
//
//    /// 테스트에서 그래프 생성
//    public static func testingGraphGeneration() {
//        Task {
//            #logInfo("🧪 테스트 환경: 의존성 그래프 생성...")
//
//            // 테스트용 의존성 등록
//            registerTestDependencies()
//
//            // 그래프 생성
//            try AutoGraphGenerator.quickGenerate()
//
//            // 순환 의존성 검사
//            try AutoGraphGenerator.shared.generateCircularDependencyReport(
//                outputDirectory: URL(fileURLWithPath: "test_graphs")
//            )
//        }
//    }
//
//    // MARK: - CI/CD Integration
//
//    /// CI/CD에서 사용할 수 있는 정적 분석
//    public static func cicdStaticAnalysis() throws {
//        #logInfo("🔍 CI/CD: 의존성 정적 분석...")
//
//        // 문서 링크 검증
//        try DocumentationValidator.quickValidate(autoFix: false)
//
//        // 순환 의존성 검사
//        CircularDependencyDetector.shared.setDetectionEnabled(true)
//        let cycles = CircularDependencyDetector.shared.detectAllCircularDependencies()
//
//        if !cycles.isEmpty {
//            #logError("❌ CI/CD 실패: \(cycles.count)개의 순환 의존성 발견")
//            for cycle in cycles {
//                #logDebug("   🔄 \(cycle.description)")
//            }
//            throw CIError.circularDependencyDetected(cycles.count)
//        }
//
//        #logInfo("✅ CI/CD 성공: 의존성 구조가 건전합니다")
//    }
//
//    // MARK: - Private Helpers
//
//    private static func registerTestDependencies() {
//        UnifiedDI.register(UserServiceProtocol.self) { MockUserService() }
//        UnifiedDI.register(NetworkServiceProtocol.self) { MockNetworkService() }
//        UnifiedDI.register(LoggerProtocol.self) { TestLogger() }
//    }
//}
//
//// MARK: - Error Types
//
//public enum CIError: Error, LocalizedError {
//    case circularDependencyDetected(Int)
//
//    public var errorDescription: String? {
//        switch self {
//        case .circularDependencyDetected(let count):
//            return "순환 의존성 \(count)개 발견됨"
//        }
//    }
//}
//
//// MARK: - Mock Services for Testing
//
//public class MockUserService: UserServiceProtocol {
//    public func getCurrentUser() async throws -> String {
//        return "Test User"
//    }
//
//    public func handleAsyncTask() async {
//        #logDebug("Mock async task")
//    }
//}
//
//public class MockNetworkService: NetworkServiceProtocol {
//    // Mock implementation
//}
//
//public class TestLogger: LoggerProtocol {
//    public func info(_ message: String) {
//        #logDebug("TEST: \(message)")
//    }
//}
//
//// MARK: - Usage Examples in App
//
///*
// AppDelegate.swift에서 사용법:
//
// ```swift
// import UIKit
// import DiContainer
//
// @main
// class AppDelegate: UIResponder, UIApplicationDelegate {
//
//     func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//
//         // 1. DI 컨테이너 부트스트랩
//         Task {
//             await DependencyContainer.bootstrap { container in
//                 // 의존성 등록
//                 container.register(UserServiceProtocol.self) { UserServiceImpl() }
//                 container.register(NetworkServiceProtocol.self) { NetworkServiceImpl() }
//             }
//
//             // 2. 개발 모드에서만 그래프 생성
//             AppIntegrationExamples.setupDevelopmentGraphGeneration()
//         }
//
//         return true
//     }
// }
// ```
//
// SwiftUI App.swift에서 사용법:
//
// ```swift
// import SwiftUI
// import DiContainer
//
// @main
// struct MyApp: App {
//
//     init() {
//         // DI 설정
//         Task {
//             await DependencyContainer.bootstrap { container in
//                 container.register(UserServiceProtocol.self) { UserServiceImpl() }
//             }
//
//             // 그래프 생성 (개발용)
//             AppIntegrationExamples.swiftUIAppIntegration()()
//         }
//     }
//
//     var body: some Scene {
//         WindowGroup {
//             ContentView()
//         }
//     }
// }
// ```
//
// 환경변수 제어:
//
// ```bash
// # Xcode Scheme에서 설정하거나 터미널에서:
// GENERATE_DEPENDENCY_GRAPH=true ./MyApp
// ```
//
// UserDefaults 제어:
//
// ```swift
// // 앱 설정에서 토글로 제어
// UserDefaults.standard.set(true, forKey: "EnableDependencyGraphGeneration")
// ```
// */
