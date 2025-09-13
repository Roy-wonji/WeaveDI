//
//  CrashFreeGuide.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 크래시 방지 의존성 주입 가이드
public enum CrashFreeGuide {
    
    /// 크래시 방지 전략 가이드 출력
    public static func printCrashPreventionStrategies() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                         🛡️ CRASH PREVENTION STRATEGIES                       ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║                          📋 CHOOSE YOUR SAFETY LEVEL                         ║
        ║                                                                               ║
        ║  🚨 HIGH RISK - Can Crash:                                                   ║
        ║  ────────────────────────────                                               ║
        ║  @ContainerRegister(\\.service)                                              ║
        ║  private var service: ServiceProtocol                                        ║
        ║                                                                               ║
        ║  ❌ Crashes if service not registered                                        ║
        ║  ❌ Complex auto-registration logic                                          ║
        ║  ❌ Hard to debug                                                            ║
        ║                                                                               ║
        ║  ✅ MEDIUM SAFETY - Controlled Crash:                                       ║
        ║  ─────────────────────────────────────                                      ║
        ║  @RequiredDependency(\\.service)                                             ║
        ║  private var service: ServiceProtocol                                        ║
        ║                                                                               ║
        ║  ✅ Clear error messages with debugging info                                 ║
        ║  ✅ Fast performance                                                         ║
        ║  ✅ Source location tracking                                                 ║
        ║                                                                               ║
        ║  🛡️ CRASH-FREE - Safe Always:                                              ║
        ║  ──────────────────────────────                                              ║
        ║  @ContainerInject(\\.service)                                                ║
        ║  private var service: ServiceProtocol?                                       ║
        ║                                                                               ║
        ║  ✅ Never crashes                                                            ║
        ║  ✅ Optional chaining support                                                ║
        ║  ✅ Perfect for optional features                                            ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 마이그레이션 가이드 출력
    public static func printMigrationGuide() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                      🔄 MIGRATION FROM CRASHING TO SAFE                      ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  STEP 1: IDENTIFY CRASH RISKS                                                ║
        ║  ─────────────────────────────                                               ║
        ║                                                                               ║
        ║  🔍 Find all @ContainerRegister usages:                                     ║
        ║  grep -r "@ContainerRegister" . --include="*.swift"                         ║
        ║                                                                               ║
        ║  STEP 2: CATEGORIZE DEPENDENCIES                                             ║
        ║  ────────────────────────────────                                            ║
        ║                                                                               ║
        ║  🔒 CORE/REQUIRED (80%):                                                    ║
        ║  // BEFORE (risky)                                                           ║
        ║  @ContainerRegister(\\.userRepository)                                       ║
        ║  private var userRepository: UserRepositoryProtocol                          ║
        ║                                                                               ║
        ║  // AFTER (safe with clear errors)                                           ║
        ║  @RequiredDependency(\\.userRepository)                                      ║
        ║  private var userRepository: UserRepositoryProtocol                          ║
        ║                                                                               ║
        ║  🛡️ OPTIONAL/FEATURES (20%):                                               ║
        ║  // BEFORE (risky)                                                           ║
        ║  @ContainerRegister(\\.analyticsService)                                     ║
        ║  private var analytics: AnalyticsServiceProtocol                             ║
        ║                                                                               ║
        ║  // AFTER (crash-free)                                                       ║
        ║  @ContainerInject(\\.analyticsService)                                       ║
        ║  private var analytics: AnalyticsServiceProtocol?                            ║
        ║                                                                               ║
        ║  STEP 3: UPDATE USAGE CODE                                                   ║
        ║  ─────────────────────────                                                   ║
        ║                                                                               ║
        ║  // BEFORE                                                                   ║
        ║  func trackEvent(_ event: String) {                                          ║
        ║      analytics.track(event) // Can crash!                                   ║
        ║  }                                                                           ║
        ║                                                                               ║
        ║  // AFTER                                                                    ║
        ║  func trackEvent(_ event: String) {                                          ║
        ║      analytics?.track(event) // Safe!                                       ║
        ║  }                                                                           ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 베스트 프랙티스 출력
    public static func printBestPractices() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                         ⭐ CRASH-FREE BEST PRACTICES                         ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  ✅ DO:                                                                      ║
        ║  ─────                                                                        ║
        ║  • Use @ContainerInject for ALL optional features                           ║
        ║  • Use @RequiredDependency for core business logic                          ║
        ║  • Always handle nil cases for optional dependencies                        ║
        ║  • Register dependencies at app startup                                      ║
        ║  • Use guard let or if let for optional dependencies                        ║
        ║  • Provide default factories for optional dependencies when needed          ║
        ║                                                                               ║
        ║  ❌ AVOID:                                                                   ║
        ║  ────────                                                                     ║
        ║  • Don't use @ContainerRegister unless absolutely necessary                  ║
        ║  • Don't force unwrap optional dependencies                                  ║
        ║  • Don't ignore nil optional dependencies silently                          ║
        ║  • Don't register dependencies lazily throughout the app                     ║
        ║                                                                               ║
        ║  🎯 DECISION MATRIX:                                                         ║
        ║  ──────────────────                                                          ║
        ║                                                                               ║
        ║  Is this dependency REQUIRED for core app functionality?                     ║
        ║  ├─ YES → Use @RequiredDependency                                           ║
        ║  └─ NO  → Use @ContainerInject                                              ║
        ║                                                                               ║
        ║  Examples:                                                                    ║
        ║  • User authentication → @RequiredDependency                                ║
        ║  • Data repositories → @RequiredDependency                                  ║
        ║  • Network services → @RequiredDependency                                   ║
        ║  • Analytics → @ContainerInject                                             ║
        ║  • Logging → @ContainerInject                                               ║
        ║  • Debug tools → @ContainerInject                                           ║
        ║  • A/B testing → @ContainerInject                                           ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 실제 예제 출력
    public static func printRealWorldExample() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                          💼 CRASH-FREE REAL WORLD EXAMPLE                    ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  class UserProfileViewModel: ObservableObject {                              ║
        ║                                                                               ║
        ║      // 🔒 REQUIRED - Core functionality (will show helpful error if missing) ║
        ║      @RequiredDependency(\\.userRepository)                                   ║
        ║      private var userRepository: UserRepositoryProtocol                       ║
        ║                                                                               ║
        ║      @RequiredDependency(\\.authService)                                      ║
        ║      private var authService: AuthServiceProtocol                             ║
        ║                                                                               ║
        ║      // 🛡️ OPTIONAL - Features (never crash, safe to be nil)               ║
        ║      @ContainerInject(\\.analytics)                                           ║
        ║      private var analytics: AnalyticsServiceProtocol?                         ║
        ║                                                                               ║
        ║      @ContainerInject(\\.crashlytics)                                         ║
        ║      private var crashlytics: CrashlyticsServiceProtocol?                     ║
        ║                                                                               ║
        ║      @ContainerInject(\\.featureFlags)                                        ║
        ║      private var featureFlags: FeatureFlagServiceProtocol?                    ║
        ║                                                                               ║
        ║      @ContainerInject(\\.debugLogger, defaultFactory: {                       ║
        ║          // Provide fallback for development                                  ║
        ║          ConsoleDebugLogger()                                                 ║
        ║      })                                                                       ║
        ║      private var debugLogger: DebugLoggerProtocol?                            ║
        ║                                                                               ║
        ║      func loadUserProfile() async {                                          ║
        ║          do {                                                                 ║
        ║              // Required dependencies - will crash with helpful message      ║
        ║              let user = try await userRepository.getCurrentUser()            ║
        ║                                                                               ║
        ║              // Optional dependencies - safe to use                          ║
        ║              analytics?.track("profile_loaded", properties: [                ║
        ║                  "user_id": user.id                                          ║
        ║              ])                                                              ║
        ║                                                                               ║
        ║              debugLogger?.log("User profile loaded successfully")            ║
        ║                                                                               ║
        ║          } catch {                                                            ║
        ║              crashlytics?.recordError(error)                                  ║
        ║              debugLogger?.log("Failed to load profile: \\(error)")            ║
        ║          }                                                                    ║
        ║      }                                                                        ║
        ║                                                                               ║
        ║      func saveProfile(_ profile: UserProfile) async {                        ║
        ║          // Feature flag check - safe even if service not registered         ║
        ║          guard featureFlags?.isEnabled("profile_editing") != false else {    ║
        ║              debugLogger?.log("Profile editing disabled by feature flag")    ║
        ║              return                                                           ║
        ║          }                                                                    ║
        ║                                                                               ║
        ║          do {                                                                 ║
        ║              try await userRepository.updateProfile(profile)                 ║
        ║              analytics?.track("profile_saved")                               ║
        ║          } catch {                                                            ║
        ║              crashlytics?.recordError(error)                                  ║
        ║          }                                                                    ║
        ║      }                                                                        ║
        ║  }                                                                            ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 모든 크래시 방지 가이드 출력
    public static func printAllCrashFreeGuides() {
        #logInfo("🛡️ Starting crash-free DiContainer guide...")
        
        printCrashPreventionStrategies()
        printMigrationGuide()
        printBestPractices()
        printRealWorldExample()
        
        #logInfo("🎉 Crash-free DiContainer guide complete!")
        #logInfo("💡 Remember: Safety first - use @ContainerInject for optional dependencies!")
    }
}