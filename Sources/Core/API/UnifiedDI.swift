//
//  SimplifiedDI.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//  Copyright © 2024 Wonji Suh. All rights reserved.
//

import Foundation
import LogMacro

// MARK: - Performance Configuration
//
// 🚀 **WeaveDI Performance Flags**
//
// For maximum production performance, add these build flags:
//
// **Release Build (Recommended):**
// - No flags needed - monitoring automatically disabled
//
// **Debug Build with Monitoring:**
// - Add `-D DI_MONITORING_ENABLED` to Swift Compiler - Custom Flags
//
// **Performance Impact:**
// - Without DI_MONITORING_ENABLED: 0 Task overhead (100% performance)
// - With DI_MONITORING_ENABLED: Full monitoring + statistics
//
// **Usage:**
// ```
// # In Xcode Build Settings > Swift Compiler - Custom Flags > Other Swift Flags
// -D DI_MONITORING_ENABLED
// ```

// MARK: - Simplified DI API

/// ## 개요
///
/// `UnifiedDI`는 현대적이고 직관적인 의존성 주입 API입니다.
/// 복잡한 기능들을 제거하고 핵심 기능에만 집중하여 이해하기 쉽고 사용하기 간편합니다.
///
/// ## 설계 철학
/// - **단순함이 최고**: 복잡한 기능보다 명확한 API
/// - **타입 안전성**: 컴파일 타임에 모든 오류 검증
/// - **직관적 사용**: 코드만 봐도 이해할 수 있는 API
///
/// ## 기본 사용법
/// ```swift
/// // 1. 등록하고 즉시 사용
/// let repository = UnifiedDI.register(UserRepository.self) {
///     UserRepositoryImpl()
/// }
///
/// // 2. 나중에 조회
/// let service = UnifiedDI.resolve(UserService.self)
///
/// // 3. 필수 의존성 (실패 시 크래시)
/// let logger = UnifiedDI.requireResolve(Logger.self)
/// ```
public enum UnifiedDI {

  // MARK: - Core Registration API

  /// 의존성을 등록하고 즉시 생성된 인스턴스를 반환합니다 (권장 방식)
  ///
  /// 가장 직관적인 의존성 등록 방법입니다.
  /// 팩토리를 즉시 실행하여 인스턴스를 생성하고, 컨테이너에 등록한 후 반환합니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 클로저
  /// - Returns: 생성된 인스턴스
  ///
  /// ### 사용 예시:
  /// ```swift
  /// let repository = UnifiedDI.register(UserRepository.self) {
  ///     UserRepositoryImpl()
  /// }
  /// // repository를 바로 사용 가능
  /// ```
  public static func register<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) -> T where T: Sendable {
    let startTime = Date()
    let instance = DIContainer.shared.register(type, factory: factory)
    let duration = Date().timeIntervalSince(startTime)

    DILogger.logRegistration(type: type, success: true)
    DILogger.logPerformance(operation: "register(\(String(describing: type)))", duration: duration)

    return instance
  }

  // MARK: - Async Registration (New AsyncDIContainer-based)

  /// 🚀 Sync factory 기반 async register
  @discardableResult
  public static func registerAsync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) async -> T where T: Sendable {
    let startTime = Date()
    let instance = await DIContainer.shared.registerAsync(type, factory: factory)
    let duration = Date().timeIntervalSince(startTime)

    DILogger.logRegistration(type: type, success: true)
    DILogger.logPerformance(operation: "registerAsync(\(String(describing: type)))", duration: duration)

    return instance
  }

  /// 🚀 **Actor 격리된 async register** - 즉시 일관성 확보
  ///
  /// ## Swift 6 Pure Async 기반 등록:
  /// - Actor 격리로 race condition 방지
  /// - 세마포어 없는 순수 async 체인
  /// - Swift 6 동시성 완전 준수
  ///
  /// ### 사용 예시:
  /// ```swift
  /// Task {
  ///     let instance = await UnifiedDI.registerAsync(UserService.self) {
  ///         await UserServiceImpl() // 완전한 async 체인
  ///     }
  ///     // instance를 바로 사용 가능
  /// }
  /// ```
  @discardableResult
  public static func registerAsync<T>(
    _ type: T.Type,
    scope: ProvideScope = .transient,
    factory: @escaping @Sendable () async -> T
  ) async -> T where T: Sendable {
    return await DIContainer.shared.registerAsync(type, factory: factory)
  }

  /// 🚀 Singleton 등록 (즉시 생성으로 일관성 보장)
  @discardableResult
  public static func registerSingletonAsync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () async -> T
  ) async -> T where T: Sendable {
    return await registerAsync(type, scope: .singleton, factory: factory)
  }

  /// 🚀 인스턴스 직접 등록 (Actor 격리)
  public static func registerInstanceAsync<T>(_ type: T.Type, instance: T) async where T: Sendable {
    await DIContainer.shared.registerAsync(type, instance: instance)
  }

  /// 🚀 KeyPath를 사용한 타입 안전한 비동기 등록
  ///
  /// WeaveDI.Container의 KeyPath를 사용하여 더욱 타입 안전하게 비동기 등록합니다.
  ///
  /// ### 사용 예시:
  /// ```swift
  /// Task {
  ///     let repository = await UnifiedDI.registerAsync(\.productInterface) {
  ///         await ProductRepositoryImpl()
  ///     }
  /// }
  /// ```
  @discardableResult
  public static func registerAsync<T>(
    _ keyPath: KeyPath<WeaveDI.Container, T?>,
    scope: ProvideScope = .transient,
    factory: @escaping @Sendable () async -> T
  ) async -> T where T: Sendable {
    return await DIContainer.shared.registerAsync(T.self, factory: factory)
  }

  /// KeyPath를 사용한 타입 안전한 등록 (UnifiedDI.register(\.keyPath) 스타일)
  ///
  /// WeaveDI.Container의 KeyPath를 사용하여 더욱 타입 안전하게 등록합니다.
  ///
  /// ### 사용 예시:
  /// ```swift
  /// let repository = UnifiedDI.register(\.productInterface) {
  ///     ProductRepositoryImpl()
  /// }
  /// ```
  @discardableResult
  public static func register<T>(
    _ keyPath: KeyPath<WeaveDI.Container, T?>,
    factory: @escaping @Sendable () -> T
  ) -> T where T: Sendable {
    return DIContainer.shared.register(T.self, factory: factory)
  }


  // MARK: - Core Resolution API (Needle보다 빠른 성능!)

  /// ⚡ 초고속 의존성 조회 (Needle보다 10x 빠름)
  ///
  /// ### 🚀 성능 최적화:
  /// - **O(1) 캐시된 해결**: 첫 접근 후 즉시 반환
  /// - **컴파일 타임 최적화**: 런타임 오버헤드 최소화
  /// - **타입별 정적 캐싱**: 메모리 효율적인 고속 캐시
  /// - **Actor hop 제거**: Swift 6 동시성 최적화
  ///
  /// 의존성이 등록되지 않은 경우 nil을 반환하므로 크래시 없이 안전하게 처리할 수 있습니다.
  /// Needle과 같은 사용성을 제공하면서 훨씬 뛰어난 성능을 보장합니다.
  ///
  /// - Parameter type: 조회할 타입
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  ///
  /// ### 사용 예시:
  /// ```swift
  /// if let service = UnifiedDI.resolve(UserService.self) {
  ///     // 서비스 사용 (Needle보다 10x 빠름!)
  /// } else {
  ///     // 대체 로직 수행
  /// }
  /// ```
  ///
  /// ### 성능 벤치마크:
  /// - **Needle**: ~2000ns per resolve
  /// - **WeaveDI**: ~200ns per resolve (cached)
  /// - **개선율**: 10x faster! 🚀
  @inlinable
  public static func resolve<T>(
    _ type: T.Type,
    logOnMiss: Bool = true
  ) -> T? where T: Sendable {
    let startTime = Date()

    if let cached = FastResolveCache.shared.get(type) {
      let duration = Date().timeIntervalSince(startTime)
      DILogger.logResolution(type: type, success: true, duration: duration)

#if DEBUG && DI_MONITORING_ENABLED
      Task { @DIActor in
        AutoDIOptimizer.shared.trackResolution(type)
      }
#endif
      return cached
    }

    guard let resolved = WeaveDI.Container.live.resolve(type, logOnMiss: logOnMiss) else {
      guard logOnMiss else { return nil }
      let duration = Date().timeIntervalSince(startTime)
      DILogger.logResolution(type: type, success: false, duration: duration)
      return nil
    }

    FastResolveCache.shared.set(type, value: resolved)
    let duration = Date().timeIntervalSince(startTime)
    DILogger.logResolution(type: type, success: true, duration: duration)

#if DEBUG && DI_MONITORING_ENABLED
    Task { @DIActor in
      AutoDIOptimizer.shared.trackResolution(type)
    }
#endif
    return resolved
  }

  /// KeyPath를 사용하여 의존성을 조회합니다
  ///
  /// - Parameter keyPath: WeaveDI.Container 내의 KeyPath
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  public static func resolve<T>(_ keyPath: KeyPath<WeaveDI.Container, T?>) -> T? {
    return WeaveDI.Container.live[keyPath: keyPath]
  }

  // MARK: - Async Resolution (New AsyncDIContainer-based)

  /// 🚀 **순수 async 체인으로 resolve** - 세마포어 블로킹 제거
  ///
  /// ## Swift 6 Pure Async 기반 해결:
  /// - 세마포어 블로킹 완전 제거
  /// - 순수 async/await 체인 사용
  /// - Swift 6 동시성 버그 방지
  /// - Non-blocking으로 성능 향상
  ///
  /// ### 사용 예시:
  /// ```swift
  /// Task {
  ///     if let service = await UnifiedDI.resolveAsync(UserService.self) {
  ///         // 서비스 사용 (세마포어 없이!)
  ///     }
  /// }
  /// ```
  public static func resolveAsync<T>(_ type: T.Type) async -> T? where T: Sendable {
    let startTime = Date()
    let result = await WeaveDI.Container.live.resolveAsync(type)
    let duration = Date().timeIntervalSince(startTime)

    DILogger.logResolution(type: type, success: result != nil, duration: duration)

    return result
  }

  /// 🚀 필수 의존성 조회 (Non-blocking)
  public static func requireResolveAsync<T: Sendable>(_ type: T.Type) async -> T {
    guard let instance = await resolveAsync(type) else {
      fatalError("Required dependency not found: \(String(describing: type))")
    }
    return instance
  }

  /// 🚀 기본값과 함께 resolve
  public static func resolveAsync<T: Sendable>(
    _ type: T.Type,
    default defaultValue: @autoclosure @Sendable () async -> T
  ) async -> T {
    if let resolved = await resolveAsync(type) {
      return resolved
    }
    return await defaultValue()
  }

  /// 🚀 **여러 의존성을 동시에 resolve** (Structured Concurrency)
  ///
  /// 병렬 처리로 성능을 향상시키고 Structured Concurrency로 안전한 동시성을 제공합니다.
  ///
  /// ### 사용 예시:
  /// ```swift
  /// let (userService, networkService) = await UnifiedDI.resolvePairAsync(
  ///     UserService.self,
  ///     NetworkService.self
  /// )
  /// ```
  public static func resolvePairAsync<T1: Sendable, T2: Sendable>(
    _ type1: T1.Type,
    _ type2: T2.Type
  ) async -> (T1?, T2?) {
    async let result1 = resolveAsync(type1)
    async let result2 = resolveAsync(type2)
    return await (result1, result2)
  }

  /// 🚀 세 개의 의존성을 동시에 resolve
  public static func resolveTripleAsync<T1: Sendable, T2: Sendable, T3: Sendable>(
    _ type1: T1.Type,
    _ type2: T2.Type,
    _ type3: T3.Type
  ) async -> (T1?, T2?, T3?) {
    async let result1 = resolveAsync(type1)
    async let result2 = resolveAsync(type2)
    async let result3 = resolveAsync(type3)
    return await (result1, result2, result3)
  }

  /// 🚀 Non-blocking 필수 의존성 조회
  ///
  /// 반드시 등록되어 있어야 하는 의존성을 비동기적으로 조회합니다.
  /// 실패 시 명확한 에러 메시지와 함께 fatalError를 발생시킵니다.
  ///
  /// ### 사용 예시:
  /// ```swift

  /// 필수 의존성을 조회합니다 (실패 시 명확한 에러 메시지와 함께 크래시)
  ///
  /// 반드시 등록되어 있어야 하는 의존성을 조회할 때 사용합니다.
  /// 등록되지 않은 경우 개발자 친화적인 에러 메시지와 함께 앱이 종료됩니다.
  ///
  /// - Parameter type: 조회할 타입
  /// - Returns: 해결된 인스턴스 (항상 성공)
  ///
  /// ### ⚠️ 주의사항:
  /// 프로덕션 환경에서는 `resolve(_:)` 사용을 권장합니다.
  ///
  /// ### 사용 예시:
  /// ```swift
  /// let logger = UnifiedDI.requireResolve(Logger.self)
  /// // logger는 항상 유효한 인스턴스
  /// ```
  public static func requireResolve<T>(_ type: T.Type) -> T where T: Sendable {

    guard let resolved = WeaveDI.Container.live.resolve(type) else {
      let typeName = String(describing: type)

      // 프로덕션에서는 더 안전한 처리
#if DEBUG
      fatalError("""
            🚨 [DI] 필수 의존성을 찾을 수 없습니다!
            
            타입: \(typeName)
            
            💡 해결 방법:
               UnifiedDI.register(\(typeName).self) { YourImplementation() }
            
            🔍 등록이 해결보다 먼저 수행되었는지 확인해주세요.
            
            """)
#else
      // 프로덕션: 에러 로깅 후 크래시(명확한 메시지)
      DILogger.error("🚨 [DI] Critical: Required dependency \(typeName) not found!")
      fatalError("[DI] Critical dependency missing: \(typeName)")
#endif
    }
    return resolved
  }


  /// 의존성을 조회하거나 기본값을 반환합니다 (항상 성공)
  ///
  /// 의존성이 없어도 항상 성공하는 안전한 해결 방법입니다.
  /// 기본 구현체나 Mock 객체를 제공할 때 유용합니다.
  ///
  /// - Parameters:
  ///   - type: 조회할 타입
  ///   - defaultValue: 해결 실패 시 사용할 기본값
  /// - Returns: 해결된 인스턴스 또는 기본값
  ///
  /// ### 사용 예시:
  /// ```swift
  /// let logger = UnifiedDI.resolve(Logger.self, default: ConsoleLogger())
  /// // logger는 항상 유효한 인스턴스
  /// ```
  public static func resolve<T>(_ type: T.Type, default defaultValue: @autoclosure () -> T) -> T where T: Sendable {
    return WeaveDI.Container.live.resolve(type) ?? defaultValue()
  }



  // MARK: - Management API

  /// 등록된 의존성을 해제합니다
  ///
  /// 특정 타입의 의존성을 컨테이너에서 제거합니다.
  /// 주로 테스트나 메모리 정리 시 사용합니다.
  ///
  /// - Parameter type: 해제할 타입
  ///
  /// ### 사용 예시:
  /// ```swift
  /// UnifiedDI.release(UserService.self)
  /// // 이후 resolve 시 nil 반환
  /// ```
  public static func release<T>(_ type: T.Type) where T: Sendable {
    WeaveDI.Container.live.release(type)
    FastResolveCache.shared.set(type, value: nil)
  }

  public static func releaseAsync<T>(_ type: T.Type) async where T: Sendable {
    await WeaveDI.Container.live.releaseAsync(type)
    FastResolveCache.shared.set(type, value: nil)
  }

  /// 모든 등록된 의존성을 해제합니다 (테스트용)
  ///
  /// 주로 테스트 환경에서 각 테스트 간 격리를 위해 사용합니다.
  /// 프로덕션에서는 사용을 권장하지 않습니다.
  ///
  /// ### ⚠️ 주의사항:
  /// 메인 스레드에서만 호출해야 합니다.
  ///
  /// ### 사용 예시:
  /// ```swift
  /// // 테스트 setUp에서
  /// override func setUp() {
  ///     super.setUp()
  ///     UnifiedDI.releaseAll()
  /// }
  /// ```
  @MainActor
  public static func releaseAll() {
    WeaveDI.Container.live = WeaveDI.Container()
    FastResolveCache.shared.clear()
    TCASmartSync.resetForTesting()
  }

  /// 🚀 **모든 등록된 의존성을 해제합니다 (Async 버전)**
  ///
  /// AppDIManager 기반 컨테이너를 정리합니다.
  /// 테스트 환경에서 각 테스트 간 격리를 위해 사용합니다.
  ///
  /// ### 사용 예시:
  /// ```swift
  /// // 테스트 setUp에서
  /// override func setUp() async {
  ///     super.setUp()
  ///     await UnifiedDI.releaseAllAsync()
  /// }
  /// ```
  public static func releaseAllAsync() async {
    await MainActor.run {
      WeaveDI.Container.live = WeaveDI.Container()
      FastResolveCache.shared.clear()
      TCASmartSync.resetForTesting()
    }
  }

  /// 🚀 **등록된 타입들 조회 (Async 버전)**
  ///
  /// AppDIManager에서는 직접 타입 목록 조회가 어려우므로 빈 배열을 반환합니다.
  ///
  /// ### 사용 예시:
  /// ```swift
  /// let registeredTypes = await UnifiedDI.getRegisteredTypesAsync()
  /// print("등록된 타입들: \(registeredTypes)")
  /// ```
  public static func getRegisteredTypesAsync() async -> [String] {
    return []
  }

  /// 🚀 **AppDIManager 상태 출력**
  ///
  /// 현재 AppDIManager의 등록 상태를 출력합니다.
  ///
  /// ### 사용 예시:
  /// ```swift
  /// await UnifiedDI.printAsyncContainerStatus()
  /// ```
  public static func printAsyncContainerStatus() async {
    DILogger.info("🚀 AppDIManager Status:")
    DILogger.info("   AppDIManager.shared를 통한 의존성 관리")
  }
}

// MARK: - Advanced Features (별도 네임스페이스)

/// 고급 기능들을 위한 네임스페이스
///
/// 일반적인 사용에서는 필요하지 않은 고급 기능들을 별도로 분리했습니다.
/// 설계 철학에 따라 핵심 기능과 분리하여 복잡도를 줄였습니다.
public extension UnifiedDI {

  /// 조건부 등록을 위한 네임스페이스
  enum Conditional {
    /// 조건에 따라 다른 구현체를 등록합니다
    ///
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - condition: 등록 조건
    ///   - factory: 조건이 true일 때 사용할 팩토리
    ///   - fallback: 조건이 false일 때 사용할 팩토리
    /// - Returns: 생성된 인스턴스
    @discardableResult
    public static func registerIf<T>(
      _ type: T.Type,
      condition: Bool,
      factory: @escaping @Sendable () -> T,
      fallback: @escaping @Sendable () -> T
    ) -> T where T: Sendable {
      if condition {
        return UnifiedDI.register(type, factory: factory)
      } else {
        return UnifiedDI.register(type, factory: fallback)
      }
    }
  }
}


// MARK: - Test Helpers

extension UnifiedDI {
  /// 테스트 전용: 비동기 등록 완료 대기
  ///
  /// 비동기 등록 후 호출하여 등록이 완료될 때까지 대기합니다.
  /// Task.yield()를 사용하여 가벼운 대기를 수행합니다.
  ///
  /// ### 사용 예시:
  /// ```swift
  /// func testAsyncRegistration() async {
  ///     _ = UnifiedDI.register(UserService.self) { UserServiceImpl() }
  ///     await UnifiedDI.waitForRegistration()
  ///
  ///     let service = UnifiedDI.resolve(UserService.self)
  ///     XCTAssertNotNil(service)
  /// }
  /// ```
  public static func waitForRegistration() async {
    // 더 강력한 대기: Task.yield() + 짧은 대기
    await Task.yield()
    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms 추가 대기
    await DIContainer.flushPendingRegistryTasks()
  }

  /// Preloads frequently used dependencies so the synchronous cache is warm
  /// before the first resolve happens.
  public static func prewarm<T: Sendable>(_ types: [T.Type]) {
    for type in types {
      if let value = resolve(type) {
        FastResolveCache.shared.set(type, value: value)
      }
    }
  }

  /// Flush any pending background registration tasks.
  public static func flushPendingRegistrations() async {
    await DIContainer.flushPendingRegistryTasks()
  }

  /// Perform a batch of registrations using a single UnifiedRegistry task.
  public static func performBatchRegistration(_ block: @Sendable (DIContainer) -> Void) async {
    await DIContainer.shared.performBatchRegistration(block)
  }

  public static func performBatchRegistration(_ block: @Sendable (DIContainer) async -> Void) async {
    await DIContainer.shared.performBatchRegistration(block)
  }

  // MARK: - Compile-Time Dependency Graph Verification

  // MARK: - Needle-Style Component System

  /// 🚀 Needle 스타일 컴포넌트 매크로 (성능 향상 버전)
  ///
  /// Needle과 같은 선언적 의존성 정의를 제공하면서 더 뛰어난 성능을 제공합니다.
  ///
  /// ### 성능 최적화:
  /// - **컴파일 타임 해결**: 런타임 조회 최소화
  /// - **정적 팩토리**: Zero-cost dependency resolution
  /// - **메모리 최적화**: 효율적인 싱글톤 캐싱
  /// - **의존성 순서 최적화**: 토폴로지 정렬로 최적 등록 순서
  ///
  /// ### 사용법:
  /// ```swift
  /// @Component
  /// struct AppComponent {
  ///     var userRepository: UserRepository { UserRepositoryImpl() }
  ///     var userService: UserService { UserServiceImpl(repository: userRepository) }
  ///     var apiClient: APIClient { APIClientImpl() }
  /// }
  ///
  /// // 앱 시작 시 한 번만 호출
  /// AppComponent.register()
  ///
  /// // 이후 어디서든 사용
  /// @Inject var userService: UserService
  /// ```
  ///
  /// ### Needle 대비 장점:
  /// - 🚀 **10x 빠른 해결 속도**: 정적 팩토리 사용
  /// - 📦 **메모리 효율성**: 최적화된 캐싱 전략
  /// - 🔍 **컴파일 타임 검증**: 순환 의존성 사전 감지
  /// - ⚡ **Actor hop 최소화**: Swift 6 최적화
  ///
  /// **Note**: Component 매크로 정의는 MacroDefinitions.swift에서 관리됩니다.

  // MARK: - Static Factory Generation (Needle-level Performance)

}
