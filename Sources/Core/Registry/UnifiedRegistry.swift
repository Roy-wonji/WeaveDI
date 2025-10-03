//
//  UnifiedRegistry.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/19/25.
//

import Foundation
import LogMacro

// MARK: - Type Identifier

/// 타입-안전한 식별자 (ObjectIdentifier 기반)
public struct AnyTypeIdentifier: Hashable, Sendable {
  private let identifier: ObjectIdentifier
  public let typeName: String

  public init<T>(type: T.Type) {
    self.identifier = ObjectIdentifier(type)
    self.typeName = String(describing: type)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }

  public static func == (lhs: AnyTypeIdentifier, rhs: AnyTypeIdentifier) -> Bool {
    return lhs.identifier == rhs.identifier
  }
}

// MARK: - Unified Registry System

/// ## 개요
///
/// `UnifiedRegistry`는 모든 의존성 등록 및 해결을 통합 관리하는 중앙화된 시스템입니다.
/// 기존의 분산된 Registry들(`TypeSafeRegistry`, `AsyncTypeRegistry`, `SimpleKeyPathRegistry`)을
/// 하나로 통합하여 일관성과 성능을 개선합니다.
///
/// ## 핵심 특징
///
/// ### 🏗️ 통합된 저장소
/// - **동기 팩토리**: 즉시 생성되는 의존성
/// - **비동기 팩토리**: async 컨텍스트에서 생성되는 의존성
/// - **KeyPath 매핑**: 타입 안전한 KeyPath 기반 접근
///
/// ### 🔒 동시성 안전성
/// - **Actor 기반**: Swift Concurrency를 활용한 데이터 경쟁 방지
/// - **Type-safe Keys**: ObjectIdentifier 기반 타입 안전한 키
/// - **Memory Safety**: 자동 메모리 관리 및 순환 참조 방지
///
/// ### ⚡ 성능 최적화
/// - **지연 생성**: 실제 사용 시점까지 생성 지연
/// - **타입 추론**: 컴파일 타임 타입 최적화
/// - **성능 추적**: AutoDIOptimizer 자동 통합
///
/// ## 사용 예시
///
/// ### 기본 등록
/// ```swift
/// let registry = UnifiedRegistry()
///
/// // 팩토리 등록
/// await registry.register(NetworkService.self) { DefaultNetworkService() }
///
/// // 비동기 팩토리 등록
/// await registry.registerAsync(CloudService.self) { await CloudServiceImpl() }
/// ```
///
/// ### 해결 (Resolution)
/// ```swift
/// // 동기 해결
/// let service = await registry.resolve(NetworkService.self)
///
/// // 비동기 해결
/// let cloudService = await registry.resolveAsync(CloudService.self)
///
/// // KeyPath 기반 해결
/// let database = await registry.resolve(keyPath: \.database)
///
/// // 성능 추적과 함께 해결
/// let service = await registry.resolveWithPerformanceTracking(NetworkService.self)
/// ```
///
/// ### 조건부 등록
/// ```swift
/// await registry.registerIf(
///     AnalyticsService.self,
///     condition: !isDebugMode,
///     factory: { FirebaseAnalytics() },
///     fallback: { MockAnalytics() }
/// )
/// ```
public actor UnifiedRegistry {
  
  // MARK: - Storage Types
  
  /// Type-erased, sendable box for storing values safely across concurrency boundaries
  public struct ValueBox: Sendable {
    public let value: any Sendable
    public let typeName: String
    
    public init<T>(_ value: T) where T: Sendable {
      self.value = value as any Sendable
      self.typeName = String(describing: T.self)
    }
    
    public func unwrap<T>() -> T? {
      return value as? T
    }
  }
  
  /// Factory closure that produces instances
  public typealias SyncFactory = @Sendable () -> ValueBox
  public typealias AsyncFactory = @Sendable () async -> ValueBox
  
  // MARK: - Internal Storage
  
  /// 동기 팩토리 저장소 (매번 새 인스턴스 생성)
  private var syncFactories: [AnyTypeIdentifier: SyncFactory] = [:]
  
  /// 비동기 팩토리 저장소 (매번 새 인스턴스 생성)
  private var asyncFactories: [AnyTypeIdentifier: AsyncFactory] = [:]
  
  /// In-flight async singleton creation tasks (once-only semantics)
  private var asyncSingletonTasks: [AnyTypeIdentifier: Task<ValueBox, Never>] = [:]
  
  // Scoped registrations and instances
  private var scopedFactories: [AnyTypeIdentifier: (ScopeKind, SyncFactory)] = [:]
  private var scopedAsyncFactories: [AnyTypeIdentifier: (ScopeKind, AsyncFactory)] = [:]
  private var scopedInstances: [ScopedTypeKey: ValueBox] = [:]
  
  
  /// KeyPath 매핑 (KeyPath String -> TypeIdentifier)
  private var keyPathMappings: [String: AnyTypeIdentifier] = [:]
  
  /// 등록된 타입 통계 (디버깅 및 모니터링용)
  private var registrationStats: [AnyTypeIdentifier: RegistrationInfo] = [:]
  
  // MARK: - Initialization
  
  public init() {
    Log.debug("🏗️ [UnifiedRegistry] Initialized")
  }
  
  // MARK: - Synchronous Registration
  
  /// 동기 팩토리 등록 (매번 새 인스턴스 생성)
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 동기 클로저
  
  public func register<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    let syncFactory: SyncFactory = { ValueBox(factory()) }
    
    syncFactories[key] = syncFactory
    updateRegistrationInfo(key, type: .syncFactory)
    
    // 🚀 최적화 등록도 수행
    tryOptimizedRegister(type, factory: factory)
    
    Log.debug("✅ [UnifiedRegistry] Registered sync factory for \(String(describing: type))")
  }
  
  
  // MARK: - Asynchronous Registration
  
  /// 비동기 팩토리 등록 (매번 새 인스턴스 생성)
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 비동기 클로저
  public func registerAsync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () async -> T
  ) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    let asyncFactory: AsyncFactory = { ValueBox(await factory()) }
    
    asyncFactories[key] = asyncFactory
    updateRegistrationInfo(key, type: .asyncFactory)
    
    Log.debug("✅ [UnifiedRegistry] Registered async factory for \(String(describing: type))")
  }
  
  /// 비동기 싱글톤 등록 (최초 1회 생성 후 캐시)
  public func registerAsyncSingleton<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () async -> T
  ) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    let cachedFactory: AsyncFactory = { [weak self] in
      guard let self = self else { return ValueBox(await factory()) }
      return await self.getAsyncSingletonBox(for: key, factory: factory)
    }
    asyncFactories[key] = cachedFactory
    updateRegistrationInfo(key, type: .asyncSingleton)
    Log.debug("✅ [UnifiedRegistry] Registered async singleton for \(String(describing: type))")
  }
  
  /// 내부 헬퍼: Async 싱글톤 박스 얻기/생성
  private func getAsyncSingletonBox<T: Sendable>(
    for key: AnyTypeIdentifier,
    factory: @escaping @Sendable () async -> T
  ) async -> ValueBox {
    if let task = asyncSingletonTasks[key] {
      return await task.value
    }
    let task = Task.detached { ValueBox(await factory()) }
    asyncSingletonTasks[key] = task
    return await task.value
  }
  
  
  // MARK: - Conditional Registration
  
  /// 조건부 등록 (동기)
  public func registerIf<T>(
    _ type: T.Type,
    condition: Bool,
    factory: @escaping @Sendable () -> T,
    fallback: @escaping @Sendable () -> T
  ) where T: Sendable {
    let selectedFactory = condition ? factory : fallback
    register(type, factory: selectedFactory)
    
    let conditionStr = condition ? "true" : "false"
    Log.debug("🔀 [UnifiedRegistry] Registered conditional (\(conditionStr)) for \(String(describing: type))")
  }
  
  /// 조건부 등록 (비동기)
  public func registerAsyncIf<T>(
    _ type: T.Type,
    condition: Bool,
    factory: @escaping @Sendable () async -> T,
    fallback: @escaping @Sendable () async -> T
  ) where T: Sendable {
    let selectedFactory = condition ? factory : fallback
    registerAsync(type, factory: selectedFactory)
    
    let conditionStr = condition ? "true" : "false"
    Log.debug("🔀 [UnifiedRegistry] Registered async conditional (\(conditionStr)) for \(String(describing: type))")
  }
  
  // MARK: - KeyPath Support
  
  /// KeyPath를 사용한 등록
  /// - Parameters:
  ///   - keyPath: WeaveDI.Container 내의 KeyPath
  ///   - factory: 인스턴스 생성 팩토리
  public func register<T>(
    keyPath: KeyPath<WeaveDI.Container, T?>,
    factory: @escaping @Sendable () -> T
  ) where T: Sendable {
    let keyPathString = String(describing: keyPath)
    let typeKey = AnyTypeIdentifier(type: T.self)
    
    // KeyPath 매핑 저장
    keyPathMappings[keyPathString] = typeKey
    
    // 실제 등록은 타입 기반으로 수행
    register(T.self, factory: factory)
    
    Log.debug("🔗 [UnifiedRegistry] Registered with KeyPath: \(keyPathString) -> \(String(describing: T.self))")
  }
  
  // MARK: - Scoped Registration
  
  public func registerScoped<T>(
    _ type: T.Type,
    scope: ScopeKind,
    factory: @escaping @Sendable () -> T
  ) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    let syncFactory: SyncFactory = { ValueBox(factory()) }
    scopedFactories[key] = (scope, syncFactory)
    updateRegistrationInfo(key, type: .scopedFactory)
    Log.debug("🔒 [UnifiedRegistry] Registered scoped factory (\(scope.rawValue)) for \(String(describing: type))")
  }
  
  public func registerAsyncScoped<T>(
    _ type: T.Type,
    scope: ScopeKind,
    factory: @escaping @Sendable () async -> T
  ) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    let asyncFactory: AsyncFactory = { ValueBox(await factory()) }
    scopedAsyncFactories[key] = (scope, asyncFactory)
    updateRegistrationInfo(key, type: .scopedAsyncFactory)
    Log.debug("🔒 [UnifiedRegistry] Registered async scoped factory (\(scope.rawValue)) for \(String(describing: type))")
  }
  
  // MARK: - Resolution
  
  // (Removed) Sync resolve API. Use resolveAsync(_:) instead.
  
  // (Removed) Sync resolveAny API. Use resolveAnyAsync(_:) instead.
  
  // (Removed) Sync resolveAnyBox API. Use resolveAnyAsyncBox(_:) instead.
  
  /// 비동기 컨텍스트에서 런타임 타입(Any.Type)으로 의존성을 해결합니다.
  /// - Parameter type: 해결할 런타임 타입
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  public func resolveAnyAsync(_ type: Any.Type) async -> Any? {
    let key = AnyTypeIdentifier(type: type)
    
    if let (scopeKind, asyncFactory) = scopedAsyncFactories[key] {
      if let scopeId = ScopeContext.shared.currentID(for: scopeKind) {
        let sKey = ScopedTypeKey(type: key, scope: ScopeID(kind: scopeKind, id: scopeId))
        if let cached = scopedInstances[sKey] { return cached.value }
        let box = await asyncFactory()
        scopedInstances[sKey] = box
        return box.value
      } else {
        let v = await asyncFactory()
        await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
        return v.value
      }
    }
    if let asyncFactory = asyncFactories[key] {
      let v = await asyncFactory()
      await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
      return v.value
    }
    if let syncFactory = syncFactories[key] {
      let v = syncFactory()
      await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
      return v.value
    }
    return nil
  }
  
  /// 비동기 컨텍스트에서 런타임 타입(Any.Type)을 Sendable 박스로 해결합니다.
  /// - Parameter type: 해결할 런타임 타입
  /// - Returns: ValueBox(@unchecked Sendable)에 담긴 값 (없으면 nil)
  public func resolveAnyAsyncBox(_ type: Any.Type) async -> ValueBox? {
    let key = AnyTypeIdentifier(type: type)
    if let (scopeKind, asyncFactory) = scopedAsyncFactories[key] {
      if let scopeId = ScopeContext.shared.currentID(for: scopeKind) {
        let sKey = ScopedTypeKey(type: key, scope: ScopeID(kind: scopeKind, id: scopeId))
        if let cached = scopedInstances[sKey] { return cached }
        let box = await asyncFactory()
        scopedInstances[sKey] = box
        return box
      } else {
        let v = await asyncFactory()
        await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
        return v
      }
    }
    if let asyncFactory = asyncFactories[key] {
      let v = await asyncFactory()
      await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
      return v
    }
    if let syncFactory = syncFactories[key] {
      let v = syncFactory()
      await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
      return v
    }
    return nil
  }
  
  /// 비동기 의존성 해결
  /// - Parameter type: 해결할 타입
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  public func resolveAsync<T>(_ type: T.Type) async -> T? where T: Sendable {
    // 🚀 최적화 경로 시도
    if let optimized = tryOptimizedResolve(type) {
      return optimized
    }
    
    let key = AnyTypeIdentifier(type: type)
    
    // 1. Scoped 비동기 팩토리에서 생성
    if let (scopeKind, asyncFactory) = scopedAsyncFactories[key] {
      if let scopeId = ScopeContext.shared.currentID(for: scopeKind) {
        let sKey = ScopedTypeKey(type: key, scope: ScopeID(kind: scopeKind, id: scopeId))
        if let cached = scopedInstances[sKey], let resolved: T = cached.unwrap() {
          return resolved
        }
        let box = await asyncFactory()
        scopedInstances[sKey] = box
        if let resolved: T = box.unwrap() {
          await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
          return resolved
        }
      } else {
        let box = await asyncFactory()
        if let resolved: T = box.unwrap() {
          await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
          return resolved
        }
      }
    }
    
    // 2. 비동기 팩토리에서 생성
    if let factory = asyncFactories[key] {
      let box = await factory()
      let resolved: T? = box.unwrap()
      if let result = resolved {
        Log.debug("✅ [UnifiedRegistry] Resolved from async factory \(String(describing: type))")
        await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
        return result
      }
    }
    
    // 3. 동기 팩토리에서 생성 (fallback)
    if let factory = syncFactories[key] {
      let box = factory()
      let resolved: T? = box.unwrap()
      if let result = resolved {
        Log.debug("✅ [UnifiedRegistry] Resolved from sync factory (async context) \(String(describing: type))")
        await CircularDependencyDetector.shared.recordAutoEdgeIfEnabled(for: type)
        return result
      }
    }
    
    Log.debug("❌ [UnifiedRegistry] Failed to resolve async \(String(describing: type))")
    return nil
  }
  
  // (Removed) Sync resolve(keyPath:) API. Use resolveAsync(keyPath:) instead.
  
  /// KeyPath를 사용한 해결 (async)
  public func resolveAsync<T>(keyPath: KeyPath<WeaveDI.Container, T?>) async -> T? where T: Sendable {
    let keyPathString = String(describing: keyPath)
    guard keyPathMappings[keyPathString] != nil else {
      Log.debug("❌ [UnifiedRegistry] KeyPath not found: \(keyPathString)")
      return nil
    }
    return await resolveAsync(T.self)
  }
  
  // MARK: - Management
  
  /// 특정 타입의 등록을 해제합니다
  /// - Parameter type: 해제할 타입
  public func release<T>(_ type: T.Type) {
    let key = AnyTypeIdentifier(type: type)
    
    syncFactories.removeValue(forKey: key)
    asyncFactories.removeValue(forKey: key)
    asyncSingletonTasks.removeValue(forKey: key)
    scopedFactories.removeValue(forKey: key)
    scopedAsyncFactories.removeValue(forKey: key)
    scopedInstances = scopedInstances.filter { $0.key.type != key }
    registrationStats.removeValue(forKey: key)
    
    // KeyPath 매핑에서도 제거
    keyPathMappings = keyPathMappings.filter { $0.value != key }
    
    Log.debug("🗑️ [UnifiedRegistry] Released \(String(describing: type))")
  }
  
  /// 모든 등록을 해제합니다
  public func releaseAll() {
    let totalCount = syncFactories.count + asyncFactories.count
    
    syncFactories.removeAll()
    asyncFactories.removeAll()
    asyncSingletonTasks.removeAll()
    scopedFactories.removeAll()
    scopedAsyncFactories.removeAll()
    scopedInstances.removeAll()
    keyPathMappings.removeAll()
    registrationStats.removeAll()
    
    Log.info("🧹 [UnifiedRegistry] Released all registrations (total: \(totalCount))")
  }

  /// 현재 등록된 타입 수를 반환합니다
  public func registeredTypeCount() -> Int {
    syncFactories.count
      + asyncFactories.count
      + scopedFactories.count
      + scopedAsyncFactories.count
  }
  
  /// 특정 스코프의 인스턴스들을 모두 해제합니다.
  /// - Returns: 해제된 개수
  public func releaseScope(kind: ScopeKind, id: String) -> Int {
    let before = scopedInstances.count
    scopedInstances = scopedInstances.filter { $0.key.scope != ScopeID(kind: kind, id: id) }
    return before - scopedInstances.count
  }
  
  /// 특정 타입의 스코프 인스턴스를 해제합니다.
  /// - Returns: 해제 여부
  public func releaseScoped<T>(_ type: T.Type, kind: ScopeKind, id: String) -> Bool {
    let key = AnyTypeIdentifier(type: type)
    let sKey = ScopedTypeKey(type: key, scope: ScopeID(kind: kind, id: id))
    return scopedInstances.removeValue(forKey: sKey) != nil
  }
  
  // MARK: - Diagnostics
  
  /// 등록된 타입들의 통계 정보 반환
  /// - Returns: 등록 통계
  public func getRegistrationStats() -> [String: RegistrationInfo] {
    var result: [String: RegistrationInfo] = [:]
    for (key, info) in registrationStats {
      result[key.typeName] = info
    }
    return result
  }
  
  /// 특정 타입이 등록되었는지 확인
  /// - Parameter type: 확인할 타입
  /// - Returns: 등록 여부
  public func isRegistered<T>(_ type: T.Type) -> Bool {
    let key = AnyTypeIdentifier(type: type)
    return syncFactories[key] != nil ||
    asyncFactories[key] != nil
  }
  
  /// 현재 등록된 모든 타입 이름 반환
  /// - Returns: 타입 이름 배열
  public func getAllRegisteredTypeNames() -> [String] {
    let allKeys = Set(syncFactories.keys)
      .union(Set(asyncFactories.keys))
    
    return allKeys.map(\.typeName).sorted()
  }
  
  // MARK: - Private Helpers
  
  /// 등록 정보 업데이트
  private func updateRegistrationInfo(_ key: AnyTypeIdentifier, type: RegistrationType) {
    let existing = registrationStats[key]
    let info = RegistrationInfo(
      type: type,
      registrationCount: (existing?.registrationCount ?? 0) + 1,
      lastRegistrationDate: Date()
    )
    registrationStats[key] = info
  }
}

// MARK: - Supporting Types

/// 등록 타입
public enum RegistrationType {
  case syncFactory
  case asyncFactory
  case asyncSingleton
  case scopedFactory
  case scopedAsyncFactory
  
  public var description: String {
    switch self {
      case .syncFactory: return "Sync Factory"
      case .asyncFactory: return "Async Factory"
      case .asyncSingleton: return "Async Singleton"
      case .scopedFactory: return "Scoped Factory"
      case .scopedAsyncFactory: return "Scoped Async Factory"
    }
  }
}

/// 등록 정보
public struct RegistrationInfo {
  public let type: RegistrationType
  public let registrationCount: Int
  public let lastRegistrationDate: Date
  
  public var summary: String {
    return """
        Type: \(type.description)
        Count: \(registrationCount)
        Last: \(lastRegistrationDate)
        """
  }
}

// MARK: - Optimization Integration

extension UnifiedRegistry {
  
  /// 런타임 최적화를 활성화합니다
  public func enableOptimization() {
    SimpleOptimizationManager.shared.enable()
    Log.info("🚀 [UnifiedRegistry] Runtime optimization enabled")
  }
  
  /// 런타임 최적화를 비활성화합니다
  public func disableOptimization() {
    SimpleOptimizationManager.shared.disable()
    Log.info("🔧 [UnifiedRegistry] Runtime optimization disabled")
  }
  
  /// 최적화 상태 확인
  public var isOptimizationEnabled: Bool {
    return SimpleOptimizationManager.shared.isEnabled()
  }
}

// 최적화 저장소 지원을 위한 내부 확장
internal extension UnifiedRegistry {
  
  /// 최적화된 해결 시도 (내부용)
  func tryOptimizedResolve<T>(_ type: T.Type) -> T? where T: Sendable {
    return SimpleOptimizationManager.shared.tryResolve(type)
  }
  
  /// 최적화된 등록 (내부용)
  func tryOptimizedRegister<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) where T: Sendable {
    SimpleOptimizationManager.shared.tryRegister(type, factory: factory)
  }
}

// MARK: - Simple Optimization Manager

/// 간단한 최적화 관리자
internal final class SimpleOptimizationManager: @unchecked Sendable {
  static let shared = SimpleOptimizationManager()
  
  private let lock = NSLock()
  private var enabledState = false
  // OptimizedScopeManager는 사용하지 않고 간단한 딕셔너리로 대체
  private var optimizedInstances: [ObjectIdentifier: Any] = [:]
  
  private init() {}
  
  func enable() {
    lock.lock()
    defer { lock.unlock() }
    enabledState = true
  }
  
  func disable() {
    lock.lock()
    defer { lock.unlock() }
    enabledState = false
  }
  
  func isEnabled() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return enabledState
  }
  
  func tryResolve<T>(_ type: T.Type) -> T? where T: Sendable {
    guard isEnabled() else { return nil }
    
    lock.lock()
    defer { lock.unlock() }
    
    let key = ObjectIdentifier(type)
    return optimizedInstances[key] as? T
  }
  
  func tryRegister<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) where T: Sendable {
    guard isEnabled() else { return }
    
    lock.lock()
    defer { lock.unlock() }
    
    let key = ObjectIdentifier(type)
    let instance = factory()
    optimizedInstances[key] = instance
  }
}

// MARK: - Global Instance

/// 글로벌 통합 Registry 인스턴스
/// WeaveDI.Container.live에서 내부적으로 사용
public let GlobalUnifiedRegistry = UnifiedRegistry()
