//
//  KeyPathContainerGuide.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// KeyPath 기반 ContainerRegister 사용 가이드
public enum KeyPathContainerGuide {
    
    /// 기본 사용법 출력
    public static func printBasicUsage() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                      🗝️ KEYPATH CONTAINERREGISTER GUIDE                     ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ 📋 BASIC REGISTRATION:                                                       ║
        ║ ─────────────────────                                                        ║
        ║                                                                               ║
        ║ // 1. 기본 등록                                                              ║
        ║ ContainerRegister.register(\\.userService) {                                 ║
        ║     UserServiceImpl()                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // 2. 인스턴스 등록                                                          ║
        ║ let sharedCache = CacheServiceImpl()                                         ║
        ║ ContainerRegister.registerInstance(\\.cacheService, instance: sharedCache)   ║
        ║                                                                               ║
        ║ // 3. 사용                                                                   ║
        ║ @ContainerInject(\\.userService)                                             ║
        ║ private var userService: UserServiceProtocol?                               ║
        ║                                                                               ║
        ║ 🎯 KEY BENEFITS:                                                             ║
        ║ ──────────────────                                                           ║
        ║ ✅ 타입 안전성 (컴파일 타임 체크)                                            ║
        ║ ✅ KeyPath 자동 완성 지원                                                   ║
        ║ ✅ ContainerInject와 동일한 KeyPath 사용                                    ║
        ║ ✅ 디버깅 시 KeyPath 이름 표시                                              ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 조건부 등록 사용법 출력
    public static func printConditionalRegistration() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                        🔀 CONDITIONAL REGISTRATION                           ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ 🔧 DEBUG/RELEASE 환경별 등록:                                                ║
        ║ ─────────────────────────────────                                           ║
        ║                                                                               ║
        ║ // Debug에서만 등록                                                          ║
        ║ ContainerRegister.registerIfDebug(\\.debugLogger) {                          ║
        ║     ConsoleDebugLogger()                                                     ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // Release에서만 등록                                                        ║
        ║ ContainerRegister.registerIfRelease(\\.analytics) {                          ║
        ║     FirebaseAnalyticsService()                                               ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 📱 플랫폼별 등록:                                                            ║
        ║ ──────────────────                                                           ║
        ║                                                                               ║
        ║ // iOS에서만 등록                                                            ║
        ║ ContainerRegister.registerIf(\\.iOSService, platform: .iOS) {               ║
        ║     IOSSpecificService()                                                     ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // macOS에서만 등록                                                          ║
        ║ ContainerRegister.registerIf(\\.macOSService, platform: .macOS) {           ║
        ║     MacOSSpecificService()                                                   ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ ⚡ 사용자 정의 조건:                                                         ║
        ║ ────────────────────────                                                     ║
        ║                                                                               ║
        ║ let featureEnabled = RemoteConfig.isFeatureEnabled("newFeature")            ║
        ║ ContainerRegister.registerWhen(\\.newFeatureService, condition: featureEnabled) { ║
        ║     NewFeatureServiceImpl()                                                  ║
        ║ }                                                                            ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 고급 기능 사용법 출력
    public static func printAdvancedFeatures() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                          ⚡ ADVANCED FEATURES                                ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ 🔄 비동기 등록:                                                              ║
        ║ ──────────────                                                               ║
        ║                                                                               ║
        ║ await ContainerRegister.registerAsync(\\.networkService) {                   ║
        ║     let config = await fetchNetworkConfig()                                  ║
        ║     return NetworkServiceImpl(config: config)                                ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 🏛️ 싱글톤 등록:                                                             ║
        ║ ──────────────                                                               ║
        ║                                                                               ║
        ║ ContainerRegister.registerSingleton(\\.databaseService) {                    ║
        ║     DatabaseServiceImpl() // 한 번만 생성됨                                 ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 💤 지연 등록:                                                               ║
        ║ ────────────                                                                 ║
        ║                                                                               ║
        ║ ContainerRegister.registerLazy(\\.expensiveService) {                        ║
        ║     ExpensiveServiceImpl() // 첫 접근 시까지 생성 지연                       ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 📦 배치 등록:                                                               ║
        ║ ────────────                                                                 ║
        ║                                                                               ║
        ║ ContainerRegister.registerMany {                                             ║
        ║     (\\.userService, { UserServiceImpl() })                                  ║
        ║     (\\.cacheService, CacheServiceImpl())                                    ║
        ║     (\\.networkService, { NetworkServiceImpl() })                            ║
        ║ }                                                                            ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// DSL 스타일 사용법 출력
    public static func printDSLStyle() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                              🎨 DSL STYLE                                    ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ ContainerRegister.configure {                                                ║
        ║     // 기본 서비스들                                                         ║
        ║     RegistrationConfig(                                                      ║
        ║         keyPath: \\.userService,                                             ║
        ║         factory: { UserServiceImpl() }                                       ║
        ║     )                                                                        ║
        ║                                                                               ║
        ║     // 싱글톤 캐시 서비스                                                    ║
        ║     RegistrationConfig(                                                      ║
        ║         keyPath: \\.cacheService,                                            ║
        ║         factory: { CacheServiceImpl() },                                     ║
        ║         singleton: true                                                      ║
        ║     )                                                                        ║
        ║                                                                               ║
        ║     // 조건부 분석 서비스                                                    ║
        ║     RegistrationConfig(                                                      ║
        ║         keyPath: \\.analyticsService,                                        ║
        ║         factory: { AnalyticsServiceImpl() },                                 ║
        ║         condition: !isDebugMode                                              ║
        ║     )                                                                        ║
        ║                                                                               ║
        ║     // 지연 로딩 서비스                                                      ║
        ║     RegistrationConfig(                                                      ║
        ║         keyPath: \\.heavyService,                                            ║
        ║         factory: { HeavyServiceImpl() },                                     ║
        ║         lazy: true                                                           ║
        ║     )                                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 실제 앱 설정 예제 출력
    public static func printRealWorldExample() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                          💼 REAL WORLD APP SETUP                            ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ // AppDelegate.swift                                                         ║
        ║ class AppDelegate: UIAppDelegate {                                           ║
        ║                                                                               ║
        ║     func application(_ application: UIApplication,                           ║
        ║                      didFinishLaunchingWithOptions options: [...]) -> Bool { ║
        ║                                                                               ║
        ║         setupDependencies()                                                  ║
        ║         return true                                                          ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║     private func setupDependencies() {                                       ║
        ║         // 🔒 Core services (필수)                                           ║
        ║         ContainerRegister.registerSingleton(\\.userRepository) {             ║
        ║             CoreDataUserRepository()                                         ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         ContainerRegister.register(\\.authService) {                         ║
        ║             AuthServiceImpl()                                                ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         ContainerRegister.register(\\.networkService) {                      ║
        ║             URLSessionNetworkService()                                       ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         // 🛡️ Optional services (환경별)                                   ║
        ║         ContainerRegister.registerIfDebug(\\.debugLogger) {                  ║
        ║             ConsoleDebugLogger()                                             ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         ContainerRegister.registerIfRelease(\\.analytics) {                  ║
        ║             FirebaseAnalyticsService()                                       ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         // 📱 플랫폼별 서비스                                                ║
        ║         ContainerRegister.registerIf(\\.hapticService, platform: .iOS) {     ║
        ║             UIHapticFeedbackService()                                        ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         // 💤 무거운 서비스들 (지연 로딩)                                    ║
        ║         ContainerRegister.registerLazy(\\.mlModelService) {                  ║
        ║             CoreMLModelService()                                             ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         // 🔄 비동기 초기화가 필요한 서비스                                  ║
        ║         Task {                                                               ║
        ║             await ContainerRegister.registerAsync(\\.cloudService) {         ║
        ║                 let config = await CloudConfig.fetch()                      ║
        ║                 return CloudServiceImpl(config: config)                     ║
        ║             }                                                                ║
        ║         }                                                                    ║
        ║     }                                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // ViewController에서 사용                                                   ║
        ║ class UserProfileViewController: UIViewController {                          ║
        ║     @RequiredDependency(\\.userRepository)                                   ║
        ║     private var userRepository: UserRepositoryProtocol                      ║
        ║                                                                               ║
        ║     @ContainerInject(\\.analytics)                                           ║
        ║     private var analytics: AnalyticsServiceProtocol?                        ║
        ║                                                                               ║
        ║     override func viewDidLoad() {                                            ║
        ║         super.viewDidLoad()                                                  ║
        ║         loadUserProfile()                                                    ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║     private func loadUserProfile() {                                         ║
        ║         Task {                                                               ║
        ║             let profile = try await userRepository.getCurrentUser()         ║
        ║             analytics?.track("profile_loaded")                              ║
        ║         }                                                                    ║
        ║     }                                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 디버깅 가이드 출력
    public static func printDebuggingGuide() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                            🐛 DEBUGGING GUIDE                               ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ 🔍 등록 상태 확인:                                                          ║
        ║ ────────────────                                                             ║
        ║                                                                               ║
        ║ // 특정 서비스 등록 확인                                                     ║
        ║ if ContainerRegister.isRegistered(\\.userService) {                          ║
        ║     print("UserService is registered ✅")                                   ║
        ║ } else {                                                                     ║
        ║     print("UserService is NOT registered ❌")                               ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 📊 전체 등록 현황 확인:                                                     ║
        ║ ─────────────────────────                                                   ║
        ║                                                                               ║
        ║ // 모든 KeyPath 등록 정보 출력                                               ║
        ║ ContainerRegister.debugPrintRegistrations()                                  ║
        ║                                                                               ║
        ║ 출력 예시:                                                                   ║
        ║ ╔═══════════════════════════════════════════════════════════════════════════╗ ║
        ║ ║                    🔍 KEYPATH REGISTRATIONS DEBUG                        ║ ║
        ║ ╠═══════════════════════════════════════════════════════════════════════════╣ ║
        ║ ║  userService             -> UserServiceProtocol                          ║ ║
        ║ ║      📍 AppDelegate.swift:23 in setupDependencies()                      ║ ║
        ║ ║  cacheService            -> CacheServiceProtocol                         ║ ║
        ║ ║      📍 AppDelegate.swift:27 in setupDependencies()                      ║ ║
        ║ ╚═══════════════════════════════════════════════════════════════════════════╝ ║
        ║                                                                               ║
        ║ 🚨 일반적인 문제들:                                                         ║
        ║ ────────────────────                                                         ║
        ║                                                                               ║
        ║ 1. "등록되지 않은 의존성" 오류                                               ║
        ║    → ContainerRegister.debugPrintRegistrations() 실행                       ║
        ║    → KeyPath 이름 확인                                                       ║
        ║    → 등록 타이밍 확인                                                        ║
        ║                                                                               ║
        ║ 2. "잘못된 타입" 오류                                                        ║
        ║    → 등록한 구현체가 올바른 프로토콜을 구현하는지 확인                       ║
        ║    → Generic 타입 매개변수 확인                                              ║
        ║                                                                               ║
        ║ 3. "순환 참조" 문제                                                          ║
        ║    → 의존성 그래프 검토                                                      ║
        ║    → 지연 초기화 사용 고려                                                   ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 모든 가이드 출력
    public static func printAllGuides() {
        #logInfo("🗝️ Starting KeyPath ContainerRegister comprehensive guide...")
        
        printBasicUsage()
        printConditionalRegistration()
        printAdvancedFeatures()
        printDSLStyle()
        printRealWorldExample()
        printDebuggingGuide()
        
        #logInfo("🎉 KeyPath ContainerRegister guide complete!")
        #logInfo("💡 Quick start: ContainerRegister.register(\\.yourService) { YourServiceImpl() }")
        #logInfo("🐛 Debugging: ContainerRegister.debugPrintRegistrations()")
    }
}