//
//  RegisterAndReturnGuide.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 등록과 동시에 반환하는 ContainerRegister 사용 가이드
public enum RegisterAndReturnGuide {
    
    /// 기본 사용법 출력
    public static func printBasicUsage() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                    🎯 REGISTER AND RETURN PATTERN                            ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ 📋 BASIC USAGE:                                                              ║
        ║ ─────────────────                                                            ║
        ║                                                                               ║
        ║ // ✅ 원하는 패턴: 등록과 동시에 값 반환                                     ║
        ║ public static var liveValue: BookListInterface = {                           ║
        ║     let repository = RegisterAndReturn.register(\\.bookListInterface) {      ║
        ║         BookListRepositoryImpl()                                             ║
        ║     }                                                                        ║
        ║     return BookListUseCaseImpl(repository: repository)                       ║
        ║ }()                                                                          ║
        ║                                                                               ║
        ║ // 🔄 비동기 버전                                                            ║
        ║ public static var liveValue: BookListInterface = {                           ║
        ║     Task {                                                                   ║
        ║         let repository = await RegisterAndReturn.registerAsync(\\.bookListInterface) { ║
        ║             await BookListRepositoryImpl()                                   ║
        ║         }                                                                    ║
        ║         return BookListUseCaseImpl(repository: repository)                   ║
        ║     }.result ?? DefaultBookListRepositoryImpl()                              ║
        ║ }()                                                                          ║
        ║                                                                               ║
        ║ // 🏛️ 싱글톤 패턴 (한 번만 생성)                                           ║
        ║ public static var liveValue: BookListInterface = {                           ║
        ║     let repository = RegisterAndReturn.registerSingleton(\\.bookListInterface) { ║
        ║         BookListRepositoryImpl() // 한 번만 생성됨                          ║
        ║     }                                                                        ║
        ║     return BookListUseCaseImpl(repository: repository)                       ║
        ║ }()                                                                          ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 조건부 등록 사용법 출력
    public static func printConditionalUsage() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                        🔀 CONDITIONAL REGISTRATION                           ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ // 🎯 조건부 등록 (조건이 false면 fallback 사용)                             ║
        ║ public static var liveValue: AnalyticsService = {                            ║
        ║     let analytics = RegisterAndReturn.registerIf(                           ║
        ║         \\.analyticsService,                                                  ║
        ║         condition: !isDebugMode,                                             ║
        ║         factory: { FirebaseAnalyticsService() },                            ║
        ║         fallback: MockAnalyticsService() // Debug에서는 Mock 사용           ║
        ║     )                                                                        ║
        ║     return analytics                                                         ║
        ║ }()                                                                          ║
        ║                                                                               ║
        ║ // 🐛 Debug 전용 등록                                                       ║
        ║ public static var liveValue: LoggerService = {                               ║
        ║     let logger = RegisterAndReturn.registerIfDebug(                         ║
        ║         \\.debugLogger,                                                       ║
        ║         factory: { DetailedConsoleLogger() },                               ║
        ║         fallback: NoOpLogger() // Release에서는 로깅 안함                   ║
        ║     )                                                                        ║
        ║     return logger                                                            ║
        ║ }()                                                                          ║
        ║                                                                               ║
        ║ // 🚀 Release 전용 등록                                                     ║
        ║ public static var liveValue: CrashReportingService = {                       ║
        ║     let crashReporting = RegisterAndReturn.registerIfRelease(               ║
        ║         \\.crashReporting,                                                    ║
        ║         factory: { CrashlyticsService() },                                  ║
        ║         fallback: MockCrashReportingService() // Debug에서는 Mock           ║
        ║     )                                                                        ║
        ║     return crashReporting                                                    ║
        ║ }()                                                                          ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 실제 사용 예제들 출력
    public static func printRealWorldExamples() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                          💼 REAL WORLD EXAMPLES                             ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ // 📚 BookList UseCase Example                                               ║
        ║ extension BookListUseCaseImpl: DependencyKey {                               ║
        ║     public static var liveValue: BookListInterface = {                       ║
        ║         let repository = RegisterAndReturn.register(\\.bookListInterface) {  ║
        ║             BookListRepositoryImpl()                                         ║
        ║         }                                                                    ║
        ║         return BookListUseCaseImpl(repository: repository)                   ║
        ║     }()                                                                      ║
        ║                                                                               ║
        ║     public static var testValue: BookListInterface =                        ║
        ║         MockBookListRepository()                                             ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // 👤 User Service Example (with multiple dependencies)                     ║
        ║ extension UserServiceImpl: DependencyKey {                                   ║
        ║     public static var liveValue: UserServiceProtocol = {                    ║
        ║         let repository = RegisterAndReturn.register(\\.userRepository) {     ║
        ║             CoreDataUserRepository()                                         ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         let networkService = RegisterAndReturn.register(\\.networkService) { ║
        ║             URLSessionNetworkService()                                       ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         let analytics = RegisterAndReturn.registerIfRelease(                ║
        ║             \\.analytics,                                                     ║
        ║             factory: { FirebaseAnalyticsService() },                        ║
        ║             fallback: NoOpAnalyticsService()                                 ║
        ║         )                                                                    ║
        ║                                                                               ║
        ║         return UserServiceImpl(                                              ║
        ║             repository: repository,                                          ║
        ║             networkService: networkService,                                  ║
        ║             analytics: analytics                                             ║
        ║         )                                                                    ║
        ║     }()                                                                      ║
        ║                                                                               ║
        ║     public static var testValue: UserServiceProtocol =                      ║
        ║         MockUserService()                                                    ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ // 🏛️ Singleton Cache Example                                              ║
        ║ extension CacheServiceImpl: DependencyKey {                                  ║
        ║     public static var liveValue: CacheServiceProtocol = {                   ║
        ║         // 싱글톤으로 등록 - 앱 전체에서 하나의 인스턴스만 사용              ║
        ║         let cache = RegisterAndReturn.registerSingleton(\\.cacheService) {   ║
        ║             InMemoryCacheService()                                           ║
        ║         }                                                                    ║
        ║         return cache                                                         ║
        ║     }()                                                                      ║
        ║                                                                               ║
        ║     public static var testValue: CacheServiceProtocol =                     ║
        ║         MockCacheService()                                                   ║
        ║ }                                                                            ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 장점과 특징 출력
    public static func printFeatures() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                              ⭐ KEY FEATURES                                 ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ 🎯 원하는 패턴 지원:                                                         ║
        ║ ──────────────────────                                                       ║
        ║ • 등록과 동시에 값 반환                                                      ║
        ║ • 직관적이고 간단한 문법                                                     ║
        ║ • 타입 추론으로 캐스팅 불필요                                                ║
        ║                                                                               ║
        ║ 🛡️ 안전성:                                                                  ║
        ║ ─────────                                                                    ║
        ║ • 강제 캐스팅 제거 (as! 불필요)                                             ║
        ║ • 타입 안전한 등록 및 반환                                                   ║
        ║ • Sendable 준수로 스레드 안전성                                              ║
        ║                                                                               ║
        ║ 🚀 고급 기능:                                                               ║
        ║ ───────────                                                                  ║
        ║ • 싱글톤 지원 (registerSingleton)                                           ║
        ║ • 조건부 등록 (registerIf)                                                  ║
        ║ • 환경별 등록 (registerIfDebug, registerIfRelease)                          ║
        ║ • 비동기 등록 지원 (registerAsync)                                          ║
        ║                                                                               ║
        ║ 🔗 호환성:                                                                  ║
        ║ ─────────                                                                    ║
        ║ • 기존 AutoRegister 시스템과 호환                                           ║
        ║ • ContainerInject에서 재사용 가능                                           ║
        ║ • DependencyKey 패턴 완벽 지원                                               ║
        ║                                                                               ║
        ║ 📊 디버깅:                                                                  ║
        ║ ────────                                                                     ║
        ║ • KeyPath 이름 로깅                                                         ║
        ║ • 인스턴스 생성 추적                                                         ║
        ║ • 등록 상태 확인 (isRegistered)                                             ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 모든 가이드 출력
    public static func printAllGuides() {
        #logInfo("🎯 Starting Register and Return pattern guide...")
        
        printBasicUsage()
        printConditionalUsage()
        printRealWorldExamples()
        printFeatures()
        
        #logInfo("🎉 Register and Return guide complete!")
        #logInfo("💡 Your preferred pattern: RegisterAndReturn.register(\\.keyPath) { Implementation() }")
        #logInfo("🛡️ Now with type safety and no casting needed!")
    }
}