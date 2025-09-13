//
//  DependencyInjectionGuide.swift  
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 의존성 주입 사용 가이드 및 베스트 프랙티스
public enum DependencyInjectionGuide {
    
    /// 프로퍼티 래퍼 선택 가이드 출력
    public static func printUsageGuide() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                        🏗️  DEPENDENCY INJECTION GUIDE                        ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║                            CHOOSE YOUR APPROACH:                             ║
        ║                                                                               ║
        ║  🔒 @RequiredDependency - FOR REQUIRED DEPENDENCIES (RECOMMENDED)           ║
        ║  ────────────────────────────────────────────────────────────────────────   ║
        ║  • Use when dependency MUST be registered                                    ║
        ║  • Fast performance (no fallback logic)                                      ║
        ║  • Clear intent and better error messages                                    ║
        ║  • Tracks source location for debugging                                      ║
        ║                                                                               ║
        ║  Example:                                                                     ║  
        ║  @RequiredDependency(\\.userService)                                         ║
        ║  private var userService: UserServiceProtocol                                ║
        ║                                                                               ║
        ║  🔄 @ContainerRegister - FOR FLEXIBLE DEPENDENCIES                          ║
        ║  ────────────────────────────────────────────────────────────────────────   ║
        ║  • Use when automatic registration might be helpful                          ║
        ║  • Has fallback and retry logic                                              ║
        ║  • More complex but handles edge cases                                       ║
        ║                                                                               ║
        ║  Example:                                                                     ║
        ║  @ContainerRegisterWrapper(\\.optionalService)                                      ║
        ║  private var service: ServiceProtocol                                        ║
        ║                                                                               ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                            📋 QUICK SETUP CHECKLIST                          ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  1️⃣ Define your interfaces/protocols                                        ║
        ║  2️⃣ Create implementations                                                  ║
        ║  3️⃣ Register dependencies at app startup                                    ║
        ║  4️⃣ Use property wrappers in your classes                                   ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 등록 예제 출력
    public static func printRegistrationExamples() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                           📝 REGISTRATION EXAMPLES                            ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  METHOD 1: Individual Registration                                           ║
        ║  ──────────────────────────────────────                                     ║
        ║                                                                               ║
        ║  AutoRegister.add(UserServiceProtocol.self) {                                ║
        ║      UserServiceImpl()                                                       ║
        ║  }                                                                           ║
        ║                                                                               ║
        ║  METHOD 2: Batch Registration (Recommended)                                  ║
        ║  ──────────────────────────────────────────────                             ║
        ║                                                                               ║
        ║  AutoRegister.addMany {                                                      ║
        ║      Registration(UserServiceProtocol.self) { UserServiceImpl() }           ║
        ║      Registration(DataRepositoryInterface.self) { DatabaseRepository() }    ║  
        ║      Registration(NetworkServiceProtocol.self) { NetworkServiceImpl() }     ║
        ║  }                                                                           ║
        ║                                                                               ║
        ║  METHOD 3: In AppDelegate                                                    ║
        ║  ──────────────────────────────────                                         ║
        ║                                                                               ║
        ║  func application(_ application: UIApplication,                              ║
        ║                   didFinishLaunchingWithOptions launchOptions: ...) -> Bool { ║
        ║                                                                               ║
        ║      AutoRegister.addMany {                                                  ║
        ║          Registration(AuthServiceProtocol.self) { AuthServiceImpl() }       ║
        ║          Registration(StorageInterface.self) { CoreDataStorage() }          ║
        ║      }                                                                       ║
        ║                                                                               ║
        ║      return true                                                             ║
        ║  }                                                                           ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 사용 예제 출력
    public static func printUsageExamples() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                             💼 USAGE EXAMPLES                                 ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  🏢 IN VIEW MODELS:                                                          ║
        ║  ─────────────────────                                                       ║
        ║                                                                               ║
        ║  class UserViewModel: ObservableObject {                                     ║
        ║      @RequiredDependency(\\.userService)                                     ║
        ║      private var userService: UserServiceProtocol                            ║
        ║                                                                               ║
        ║      @RequiredDependency(\\.authRepository)                                  ║
        ║      private var authRepository: AuthRepositoryInterface                     ║
        ║                                                                               ║
        ║      func loadUser() async {                                                 ║
        ║          let user = await userService.getCurrentUser()                       ║
        ║          // Use user...                                                      ║
        ║      }                                                                       ║
        ║  }                                                                           ║
        ║                                                                               ║
        ║  🏪 IN REPOSITORIES:                                                         ║
        ║  ──────────────────────                                                      ║
        ║                                                                               ║
        ║  class UserRepositoryImpl: UserRepositoryInterface {                        ║
        ║      @RequiredDependency(\\.networkService)                                  ║
        ║      private var networkService: NetworkServiceProtocol                      ║
        ║                                                                               ║
        ║      @RequiredDependency(\\.cacheStorage)                                    ║
        ║      private var cache: CacheStorageInterface                                ║
        ║                                                                               ║
        ║      func fetchUser(id: String) async throws -> User {                       ║
        ║          if let cachedUser = cache.getUser(id) {                             ║
        ║              return cachedUser                                               ║
        ║          }                                                                   ║
        ║          return try await networkService.fetchUser(id)                       ║
        ║      }                                                                       ║
        ║  }                                                                           ║
        ║                                                                               ║
        ║  🎬 IN USE CASES:                                                            ║
        ║  ───────────────────                                                         ║
        ║                                                                               ║
        ║  class LoginUseCaseImpl: LoginUseCaseProtocol {                              ║
        ║      @RequiredDependency(\\.authRepository)                                  ║
        ║      private var authRepository: AuthRepositoryInterface                     ║
        ║                                                                               ║
        ║      @RequiredDependency(\\.userRepository)                                  ║
        ║      private var userRepository: UserRepositoryInterface                     ║
        ║                                                                               ║
        ║      func login(email: String, password: String) async throws -> User {      ║
        ║          let token = try await authRepository.authenticate(email, password)  ║
        ║          return try await userRepository.getUserProfile(token: token)        ║
        ║      }                                                                       ║
        ║  }                                                                           ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 베스트 프랙티스 출력
    public static func printBestPractices() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                           ⭐ BEST PRACTICES                                   ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  ✅ DO:                                                                      ║
        ║  ─────                                                                        ║
        ║  • Use @RequiredDependency for dependencies that must be registered          ║
        ║  • Register all dependencies at app startup (AppDelegate/App.swift)         ║
        ║  • Follow consistent naming: Interface/Protocol suffix                       ║
        ║  • Use batch registration with AutoRegister.addMany                          ║
        ║  • Keep interfaces focused and cohesive                                      ║
        ║  • Test your dependency registration in unit tests                           ║
        ║                                                                               ║
        ║  ❌ DON'T:                                                                   ║
        ║  ────────                                                                     ║
        ║  • Don't register dependencies lazy in random places                         ║
        ║  • Don't create circular dependencies                                        ║
        ║  • Don't use @ContainerRegister for required dependencies                    ║
        ║  • Don't access dependencies before registration                             ║
        ║  • Don't mix different DI patterns in the same project                       ║
        ║  • Don't ignore error messages (they contain helpful information)           ║
        ║                                                                               ║
        ║  🚨 DEBUGGING TIPS:                                                          ║
        ║  ─────────────────────                                                       ║
        ║  • Check error messages for suggested implementations                        ║
        ║  • Verify your implementation classes have public initializers              ║
        ║  • Use AutoRegistrationRegistry.shared.debugPrintRegisteredTypes()          ║
        ║  • Check registration timing (must happen before first usage)               ║
        ║  • Look for similar type names in error messages                             ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// 전체 가이드 출력
    public static func printCompleteGuide() {
        printUsageGuide()
        printRegistrationExamples() 
        printUsageExamples()
        printBestPractices()
        
        #logInfo("🎉 Ready to use DiContainer with confidence!")
    }
}

// MARK: - Performance Comparison

/// 성능 비교 및 벤치마킹 유틸리티
public enum DIPerformanceInfo {
    
    /// 프로퍼티 래퍼별 성능 특성 출력
    public static func printPerformanceComparison() {
        #logInfo("""
        ╔═══════════════════════════════════════════════════════════════════════════════╗
        ║                        ⚡ PERFORMANCE COMPARISON                              ║
        ╠═══════════════════════════════════════════════════════════════════════════════╣
        ║                                                                               ║
        ║  PROPERTY WRAPPER      │ PERFORMANCE │ COMPLEXITY │ ERROR QUALITY │ USE CASE ║
        ║  ─────────────────────┼─────────────┼────────────┼───────────────┼──────── ║
        ║  @RequiredDependency   │     ⚡⚡⚡    │     🟢     │      ⭐⭐⭐     │ Required ║
        ║  @ContainerRegister    │     ⚡⚡     │     🟡     │      ⭐⭐      │ Flexible ║
        ║                                                                               ║
        ║  LEGEND:                                                                      ║
        ║  ⚡ = Fast, 🟢 = Simple, 🟡 = Moderate, ⭐ = Quality                        ║
        ║                                                                               ║
        ║  RECOMMENDATION:                                                              ║
        ║  Use @RequiredDependency for 80% of your dependencies                        ║
        ║  Use @ContainerRegister only when you need automatic fallback               ║
        ║                                                                               ║
        ╚═══════════════════════════════════════════════════════════════════════════════╝
        """)
    }
}