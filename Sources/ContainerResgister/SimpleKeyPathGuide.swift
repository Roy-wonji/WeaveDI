//
//  SimpleKeyPathGuide.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 간단한 KeyPath Registry 사용 가이드
public enum SimpleKeyPathGuide {
    
    /// 기본 사용법 출력
    public static func printBasicUsage() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                     🗝️ SIMPLE KEYPATH REGISTRY GUIDE                       ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ 📋 BASIC USAGE:                                                              ║
        ║ ─────────────────                                                            ║
        ║                                                                               ║
        ║ // 1. 기본 등록                                                              ║
        ║ SimpleKeyPathRegistry.register(\\.userService) {                             ║
        ║     UserServiceImpl()                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // 2. 인스턴스 등록                                                          ║
        ║ let sharedCache = CacheServiceImpl()                                         ║
        ║ SimpleKeyPathRegistry.registerInstance(\\.cacheService, instance: sharedCache) ║
        ║                                                                               ║
        ║ // 3. 조건부 등록                                                            ║
        ║ SimpleKeyPathRegistry.registerIf(\\.analytics, condition: !isDebug) {        ║
        ║     AnalyticsServiceImpl()                                                   ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // 4. 환경별 등록                                                            ║
        ║ SimpleKeyPathRegistry.registerIfDebug(\\.debugLogger) {                      ║
        ║     ConsoleDebugLogger()                                                     ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // 5. 사용                                                                   ║
        ║ @ContainerInject(\\.userService)                                             ║
        ║ private var userService: UserServiceProtocol?                               ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// DependencyKey 안전 패턴 출력
    public static func printSafeDependencyKeyPattern() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                        🛡️ SAFE DEPENDENCYKEY PATTERN                       ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ ❌ BEFORE (문제가 있는 패턴):                                                ║
        ║ ─────────────────────────────────                                           ║
        ║                                                                               ║
        ║ extension BookListUseCaseImpl: DependencyKey {                               ║
        ║   public static var liveValue: BookListInterface = {                        ║
        ║     let repository = ContainerRegister.register(\\.bookListInterface) {      ║
        ║       BookListRepositoryImpl()                                               ║
        ║     }                                                                        ║
        ║     return BookListUseCaseImpl(repository: repository as! BookListInterface) ║
        ║   }()                                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ ✅ AFTER (안전한 패턴):                                                     ║
        ║ ────────────────────────                                                     ║
        ║                                                                               ║
        ║ // 1. AppDelegate에서 사전 등록                                              ║
        ║ func setupDependencies() {                                                   ║
        ║   SimpleKeyPathRegistry.register(\\.bookListInterface) {                     ║
        ║     BookListRepositoryImpl()                                                 ║
        ║   }                                                                          ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // 2. DependencyKey에서 안전한 해결                                          ║
        ║ extension BookListUseCaseImpl: DependencyKey {                               ║
        ║   public static var liveValue: BookListInterface = {                        ║
        ║     return SimpleSafeDependencyRegister.resolveWithFallback(                ║
        ║       \\.bookListInterface,                                                  ║
        ║       fallback: DefaultBookListRepositoryImpl()                             ║
        ║     )                                                                        ║
        ║   }()                                                                        ║
        ║                                                                               ║
        ║   public static var testValue: BookListInterface =                          ║
        ║     DefaultBookListRepositoryImpl()                                          ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 💡 핵심 원칙:                                                               ║
        ║ • 등록은 앱 시작 시 (AppDelegate/App.swift)                                  ║
        ║ • 사용은 필요한 곳에서 (ViewController/ViewModel)                            ║
        ║ • DependencyKey는 이미 등록된 것을 해결만                                    ║
        ║ • 항상 fallback 제공으로 안전성 확보                                        ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 실제 앱 설정 예제 출력
    public static func printAppSetupExample() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                          💼 REAL WORLD APP SETUP                            ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ // AppDelegate.swift 또는 App.swift                                          ║
        ║ func setupDependencies() {                                                   ║
        ║     // 🔒 Core services (필수)                                               ║
        ║     SimpleKeyPathRegistry.register(\\.userRepository) {                      ║
        ║         CoreDataUserRepository()                                             ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║     SimpleKeyPathRegistry.register(\\.authService) {                         ║
        ║         AuthServiceImpl()                                                    ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║     SimpleKeyPathRegistry.register(\\.networkService) {                      ║
        ║         URLSessionNetworkService()                                           ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║     // 🛡️ Optional services (환경별)                                       ║
        ║     SimpleKeyPathRegistry.registerIfDebug(\\.debugLogger) {                  ║
        ║         ConsoleDebugLogger()                                                 ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║     SimpleKeyPathRegistry.registerIfRelease(\\.analytics) {                  ║
        ║         FirebaseAnalyticsService()                                           ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║     // 📦 인스턴스 등록                                                      ║
        ║     let sharedCache = MemoryCacheService()                                   ║
        ║     SimpleKeyPathRegistry.registerInstance(\\.cacheService, instance: sharedCache) ║
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
        ║ if SimpleKeyPathRegistry.isRegistered(\\.userService) {                      ║
        ║     print("UserService is registered ✅")                                   ║
        ║ } else {                                                                     ║
        ║     print("UserService is NOT registered ❌")                               ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 📊 전체 등록 현황 확인:                                                     ║
        ║ ─────────────────────────                                                   ║
        ║                                                                               ║
        ║ // AutoRegistrationRegistry 디버깅 출력                                     ║
        ║ AutoRegistrationRegistry.shared.debugPrintRegisteredTypes()                  ║
        ║                                                                               ║
        ║ 🚨 일반적인 문제들:                                                         ║
        ║ ────────────────────                                                         ║
        ║                                                                               ║
        ║ 1. "등록되지 않은 의존성" 오류                                               ║
        ║    → SimpleKeyPathRegistry.isRegistered(\\.yourService) 확인                ║
        ║    → 등록 타이밍 확인 (앱 시작 시 등록했는지)                               ║
        ║    → KeyPath 이름 확인                                                       ║
        ║                                                                               ║
        ║ 2. "잘못된 타입" 오류                                                        ║
        ║    → 등록한 구현체가 올바른 프로토콜을 구현하는지 확인                       ║
        ║    → Generic 타입 매개변수 확인                                              ║
        ║                                                                               ║
        ║ 3. DependencyKey에서 nil 반환                                                ║
        ║    → SimpleSafeDependencyRegister.safeResolve() 사용해서 디버깅              ║
        ║    → fallback이 제대로 설정되어 있는지 확인                                  ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 모든 가이드 출력
    public static func printAllGuides() {
        #logInfo("🗝️ Starting Simple KeyPath Registry comprehensive guide...")
        
        printBasicUsage()
        printSafeDependencyKeyPattern()
        printAppSetupExample()
        printDebuggingGuide()
        
        #logInfo("🎉 Simple KeyPath Registry guide complete!")
        #logInfo("💡 Quick start: SimpleKeyPathRegistry.register(\\.yourService) { YourServiceImpl() }")
        #logInfo("🛡️ For safe DependencyKey: SimpleSafeDependencyRegister.resolveWithFallback(\\.service, fallback: DefaultImpl())")
    }
}