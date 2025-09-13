//
//  ComprehensiveDIGuide.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 전체 의존성 주입 시스템 가이드
public enum ComprehensiveDIGuide {
    
    /// 3가지 프로퍼티 래퍼 비교표 출력
    public static func printPropertyWrapperComparison() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                    🏗️ DEPENDENCY INJECTION PROPERTY WRAPPERS                ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ WRAPPER              │ CRASH │ PERFORMANCE │ COMPLEXITY │ ERROR QUALITY     ║
        ║ ─────────────────────┼───────┼─────────────┼────────────┼─────────────────── ║
        ║ @RequiredDependency  │  🚨   │     ⚡⚡⚡    │     🟢     │       ⭐⭐⭐       ║
        ║ @ContainerRegister   │  🚨   │     ⚡⚡     │     🟡     │       ⭐⭐        ║
        ║ @ContainerInject     │  🛡️   │     ⚡⚡     │     🟢     │       ⭐⭐⭐       ║
        ║                                                                               ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                              📋 WHEN TO USE EACH                             ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ 🔒 @RequiredDependency:                                                      ║
        ║   • Core business logic dependencies                                         ║
        ║   • Services that are essential for app functionality                        ║
        ║   • 80% of your dependencies should use this                                 ║
        ║                                                                               ║
        ║ 🔄 @ContainerRegister:                                                       ║
        ║   • When you need automatic registration fallback                           ║
        ║   • Complex initialization scenarios                                         ║
        ║   • Legacy code migration                                                    ║
        ║                                                                               ║
        ║ 🛡️ @ContainerInject:                                                        ║
        ║   • Optional features (analytics, logging, metrics)                         ║
        ║   • Feature flags and A/B testing                                           ║
        ║   • Environment-specific services                                            ║
        ║   • Third-party SDK integrations                                            ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 실제 사용 예제들 출력
    public static func printRealWorldExamples() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                          💼 REAL WORLD USAGE EXAMPLES                        ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ 📱 TYPICAL VIEWMODEL:                                                        ║
        ║ ──────────────────────                                                       ║
        ║                                                                               ║
        ║ class UserProfileViewModel: ObservableObject {                               ║
        ║     // Required - Core functionality                                         ║
        ║     @RequiredDependency(\\.userRepository)                                   ║
        ║     private var userRepository: UserRepositoryInterface                      ║
        ║                                                                               ║
        ║     @RequiredDependency(\\.authService)                                      ║
        ║     private var authService: AuthServiceProtocol                             ║
        ║                                                                               ║
        ║     // Optional - Analytics                                                  ║
        ║     @ContainerInject(\\.analytics)                                           ║
        ║     private var analytics: AnalyticsServiceProtocol?                         ║
        ║                                                                               ║
        ║     // Optional - Feature flag                                               ║
        ║     @ContainerInject(\\.featureFlags)                                        ║
        ║     private var featureFlags: FeatureFlagServiceProtocol?                    ║
        ║                                                                               ║
        ║     func loadUserProfile() async {                                           ║
        ║         do {                                                                 ║
        ║             let user = try await userRepository.getCurrentUser()             ║
        ║             // Analytics is optional - safe to call                          ║
        ║             analytics?.track("profile_loaded", properties: [                 ║
        ║                 "user_id": user.id                                           ║
        ║             ])                                                               ║
        ║         } catch {                                                            ║
        ║             // Handle error...                                               ║
        ║         }                                                                    ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║     func saveProfile(_ profile: UserProfile) async {                        ║
        ║         // Check feature flag before saving                                  ║
        ║         guard featureFlags?.isEnabled("profile_editing") != false else {    ║
        ║             return                                                           ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         do {                                                                 ║
        ║             try await userRepository.updateProfile(profile)                  ║
        ║             analytics?.track("profile_saved")                                ║
        ║         } catch {                                                            ║
        ║             // Handle error...                                               ║
        ║         }                                                                    ║
        ║     }                                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                              🏪 REPOSITORY EXAMPLE                           ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ class UserRepositoryImpl: UserRepositoryInterface {                         ║
        ║     // Required - Network service                                            ║
        ║     @RequiredDependency(\\.networkService)                                   ║
        ║     private var networkService: NetworkServiceProtocol                       ║
        ║                                                                               ║
        ║     // Required - Cache storage                                              ║
        ║     @RequiredDependency(\\.cacheStorage)                                     ║
        ║     private var cache: CacheStorageInterface                                 ║
        ║                                                                               ║
        ║     // Optional - Debug logging                                              ║
        ║     @ContainerInject(\\.debugLogger)                                         ║
        ║     private var debugLogger: DebugLoggerProtocol?                            ║
        ║                                                                               ║
        ║     func fetchUser(id: String) async throws -> User {                       ║
        ║         debugLogger?.log("Fetching user with ID: \\(id)")                    ║
        ║                                                                               ║
        ║         // Try cache first                                                   ║
        ║         if let cachedUser = cache.getUser(id: id) {                          ║
        ║             debugLogger?.log("User found in cache")                          ║
        ║             return cachedUser                                                ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         // Fetch from network                                                ║
        ║         let user = try await networkService.fetchUser(id: id)                ║
        ║         cache.setUser(user, id: id)                                          ║
        ║                                                                               ║
        ║         debugLogger?.log("User fetched from network and cached")             ║
        ║         return user                                                          ║
        ║     }                                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 앱 설정 예제 출력
    public static func printAppSetupExample() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                            🚀 APP SETUP EXAMPLE                              ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ // AppDelegate.swift or App.swift                                            ║
        ║                                                                               ║
        ║ func application(_ application: UIApplication,                               ║
        ║                  didFinishLaunchingWithOptions launchOptions: ...) -> Bool { ║
        ║                                                                               ║
        ║     // Register REQUIRED dependencies first                                  ║
        ║     AutoRegister.addMany {                                                   ║
        ║         // Core services - MUST be registered                               ║
        ║         Registration(UserRepositoryInterface.self) {                        ║
        ║             UserRepositoryImpl()                                             ║
        ║         }                                                                    ║
        ║         Registration(AuthServiceProtocol.self) {                            ║
        ║             AuthServiceImpl()                                                ║
        ║         }                                                                    ║
        ║         Registration(NetworkServiceProtocol.self) {                         ║
        ║             NetworkServiceImpl()                                             ║
        ║         }                                                                    ║
        ║         Registration(CacheStorageInterface.self) {                          ║
        ║             CoreDataCacheStorage()                                           ║
        ║         }                                                                    ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║     // Register OPTIONAL dependencies                                        ║
        ║     #if DEBUG                                                                ║
        ║     AutoRegister.addMany {                                                   ║
        ║         Registration(DebugLoggerProtocol.self) {                            ║
        ║             ConsoleDebugLogger()                                             ║
        ║         }                                                                    ║
        ║     }                                                                        ║
        ║     #endif                                                                   ║
        ║                                                                               ║
        ║     // Register analytics only in production                                 ║
        ║     #if !DEBUG                                                               ║
        ║     AutoRegister.addMany {                                                   ║
        ║         Registration(AnalyticsServiceProtocol.self) {                       ║
        ║             FirebaseAnalyticsService()                                       ║
        ║         }                                                                    ║
        ║     }                                                                        ║
        ║     #endif                                                                   ║
        ║                                                                               ║
        ║     // Feature flags - always register                                       ║
        ║     AutoRegister.addMany {                                                   ║
        ║         Registration(FeatureFlagServiceProtocol.self) {                     ║
        ║             RemoteConfigService()                                            ║
        ║         }                                                                    ║
        ║     }                                                                        ║
        ║                                                                               ║
        ║     return true                                                              ║
        ║ }                                                                            ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 디버깅 가이드 출력
    public static func printDebuggingGuide() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                              🐛 DEBUGGING GUIDE                              ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║ 🔍 DEBUGGING OPTIONAL DEPENDENCIES:                                          ║
        ║ ─────────────────────────────────────────                                   ║
        ║                                                                               ║
        ║ class DebuggableViewModel {                                                  ║
        ║     @ContainerInject(\\.analytics)                                           ║
        ║     private var analytics: AnalyticsServiceProtocol?                         ║
        ║                                                                               ║
        ║     func debugDependencies() {                                               ║
        ║         // Check if dependency is resolved                                   ║
        ║         if $analytics.isResolved {                                           ║
        ║             print("✅ Analytics service is available")                       ║
        ║         } else {                                                             ║
        ║             print("⚠️ Analytics service is not registered")                 ║
        ║         }                                                                    ║
        ║                                                                               ║
        ║         // Print detailed debug info                                         ║
        ║         $analytics.printDebugInfo()                                          ║
        ║     }                                                                        ║
        ║ }                                                                            ║
        ║                                                                               ║
        ║ 📊 SYSTEM-WIDE DEBUGGING:                                                   ║
        ║ ─────────────────────────────                                               ║
        ║                                                                               ║
        ║ // Print all registered dependencies                                         ║
        ║ AutoRegistrationRegistry.shared.debugPrintRegisteredTypes()                  ║
        ║                                                                               ║
        ║ // Print comprehensive DI guide                                              ║
        ║ ComprehensiveDIGuide.printAllGuides()                                        ║
        ║                                                                               ║
        ║ 🚨 COMMON ISSUES:                                                           ║
        ║ ──────────────────                                                           ║
        ║                                                                               ║
        ║ 1. "Required dependency not found":                                          ║
        ║    → Check registration in AppDelegate                                       ║
        ║    → Verify implementation class exists                                      ║
        ║    → Check public initializer                                                ║
        ║                                                                               ║
        ║ 2. "Optional dependency always nil":                                         ║
        ║    → Check registration timing                                               ║
        ║    → Verify KeyPath is correct                                               ║
        ║    → Use $dependency.printDebugInfo()                                        ║
        ║                                                                               ║
        ║ 3. "Circular dependency":                                                    ║
        ║    → Review dependency graph                                                 ║
        ║    → Consider dependency inversion                                           ║
        ║    → Use interfaces to break cycles                                          ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 모든 가이드 출력
    public static func printAllGuides() {
        #logInfo("🏗️ Starting comprehensive DiContainer guide...")
        
        printPropertyWrapperComparison()
        printRealWorldExamples()
        printAppSetupExample()
        printDebuggingGuide()
        
        #logInfo("🎉 DiContainer comprehensive guide complete!")
        #logInfo("💡 For more help: DependencyInjectionGuide.printCompleteGuide()")
        #logInfo("📊 For performance info: DIPerformanceInfo.printPerformanceComparison()")
        #logInfo("🛡️ For optional dependencies: ContainerInjectGuide.printUsageExamples()")
    }
}