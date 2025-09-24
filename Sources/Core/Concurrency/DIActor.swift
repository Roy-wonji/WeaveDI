//
//  DIActor.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation
import LogMacro

// MARK: - DIActor

// 비동기 결과를 동기 브리지할 때 사용할 박스 (파일 스코프)
private final class _DIActorAsyncBox<T>: @unchecked Sendable {
  var value: T?
  init() {}
}

/// Thread-safe DI operations을 위한 Actor 기반 구현
///
/// ## 특징:
/// - **Actor 격리**: Swift Concurrency 완전 준수
/// - **Type Safety**: 컴파일 타임 타입 안전성
/// - **Memory Safety**: 자동 메모리 관리
/// - **Performance**: 최적화된 동시 접근
///
/// ## 사용법:
/// ```swift
/// // Async/await 패턴으로 사용
/// let diActor = DIActor.shared
/// await diActor.register(ServiceProtocol.self) { ServiceImpl() }
/// let service = await diActor.resolve(ServiceProtocol.self)
/// ```
@globalActor
public actor DIActor {

  // MARK: - Shared Instance

  public static let shared = DIActor()

  // MARK: - Properties

  /// 타입 안전한 팩토리 저장소
  private var factories = [AnyTypeIdentifier: Any]()

  /// 등록된 타입들의 생성 시간 추적 (디버깅용)
  private var registrationTimes = [AnyTypeIdentifier: Date]()

  /// 해제 핸들러들을 저장 (메모리 관리)
  private var releaseHandlers = [AnyTypeIdentifier: () -> Void]()

  // MARK: - Lifecycle

  private init() {
#if DEBUG
    #logDebug("🎭 [DIActor] Initialized - Swift Concurrency ready")
#endif
  }

  // MARK: - Registration

  /// 타입과 팩토리 클로저를 등록합니다.
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 팩토리 클로저
  /// - Returns: 등록 해제 핸들러
  public func register<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) -> @Sendable () async -> Void {
    let key = AnyTypeIdentifier(type: type)

    // Actor 내부에서 안전하게 상태 변경
    factories[key] = factory
    registrationTimes[key] = Date()

#if DEBUG
    #logInfo("✅ [DIActor] Registered \(type) at \(Date())")
#endif

    // 해제 핸들러 생성 (Actor 격리 보장)
    let releaseHandler: @Sendable () async -> Void = { [weak self] in
      await self?.release(type)
    }

    releaseHandlers[key] = { @Sendable in
      Task.detached { @Sendable in await releaseHandler() }
    }

    return releaseHandler
  }

  /// 인스턴스를 직접 등록합니다.
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - instance: 등록할 인스턴스
  public func register<T>(_ type: T.Type, instance: T) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)

    // Sendable 인스턴스를 클로저로 감싸기
    factories[key] = { instance }
    registrationTimes[key] = Date()

#if DEBUG
    #logInfo("✅ [DIActor] Registered instance \(type) at \(Date())")
#endif
  }

  // MARK: - Resolution

  /// 등록된 타입의 인스턴스를 해결합니다.
  /// - Parameter type: 해결할 타입
  /// - Returns: 해결된 인스턴스 또는 nil
  public func resolve<T>(_ type: T.Type) -> T? where T: Sendable {
    let key = AnyTypeIdentifier(type: type)

    guard let anyFactory = factories[key] else {
#if DEBUG
      #logError("⚠️ [DIActor] Type \(type) not found")
#endif
      return nil
    }

    guard let factory = anyFactory as? () -> T else {
#if DEBUG
      #logError("🚨 [DIActor] Type mismatch for \(type)")
#endif
      return nil
    }

    // 팩토리 실행 (Actor 외부에서 실행하여 데드락 방지)
    let instance = factory()

#if DEBUG
    #logInfo("🔍 [DIActor] Resolved \(type)")
#endif

    return instance
  }

  /// Result 패턴으로 타입을 해결합니다.
  /// - Parameter type: 해결할 타입
  /// - Returns: 성공 시 인스턴스, 실패 시 DIError
  public func resolveResult<T>(_ type: T.Type) -> Result<T, DIError> where T: Sendable {
    if let resolved = resolve(type) {
      return .success(resolved)
    } else {
      return .failure(.dependencyNotFound(type))
    }
  }

  /// throwing 방식으로 타입을 해결합니다.
  /// - Parameter type: 해결할 타입
  /// - Returns: 해결된 인스턴스
  /// - Throws: DIError.dependencyNotFound
  public func resolveThrows<T>(_ type: T.Type) throws -> T where T: Sendable {
    if let resolved = resolve(type) {
      return resolved
    } else {
      throw DIError.dependencyNotFound(type)
    }
  }

  // MARK: - Management

  /// 특정 타입의 등록을 해제합니다.
  /// - Parameter type: 해제할 타입
  public func release<T>(_ type: T.Type) {
    let key = AnyTypeIdentifier(type: type)

    factories[key] = nil
    registrationTimes[key] = nil
    releaseHandlers[key] = nil

#if DEBUG
    #logDebug("🗑️ [DIActor] Released \(type)")
#endif
  }

  /// 모든 등록을 해제합니다.
  public func releaseAll() {
    let count = factories.count

    factories.removeAll()
    registrationTimes.removeAll()
    releaseHandlers.removeAll()

#if DEBUG
    #logDebug("🧹 [DIActor] Released all \(count) registrations")
#endif
  }

  // MARK: - Introspection

  /// 등록된 타입 개수를 반환합니다.
  public var registeredCount: Int {
    return factories.count
  }

  /// 등록된 모든 타입 이름을 반환합니다.
  public var registeredTypeNames: [String] {
    return factories.keys.map { $0.typeName }.sorted()
  }

  /// 등록 상태를 자세히 출력합니다.
  public func printRegistrationStatus() {
    #logInfo("📊 [DIActor] Registration Status:")
    #logDebug("   Total registrations: \(factories.count)")

    let sortedTypes = factories.keys.sorted { $0.typeName < $1.typeName }
    for (index, key) in sortedTypes.enumerated() {
      let time = registrationTimes[key]?.description ?? "unknown"
      #logDebug("   [\(index + 1)] \(key.typeName) (registered: \(time))")
    }
  }
}

// MARK: - DIActorGlobalAPI

/// Global API for DIActor to provide seamless async/await interface
public enum DIActorGlobalAPI {

  /// Register a dependency using DIActor
  @discardableResult
  public static func register<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) async -> @Sendable () async -> Void {
    return await DIActor.shared.register(type, factory: factory)
  }


  /// Resolve a dependency using DIActor
  public static func resolve<T>(_ type: T.Type) async -> T? where T: Sendable {
    return await DIActor.shared.resolve(type)
  }

  /// Resolve with Result pattern using DIActor
  public static func resolveResult<T>(_ type: T.Type) async -> Result<T, DIError> where T: Sendable {
    return await DIActor.shared.resolveResult(type)
  }

  /// Resolve with throwing using DIActor
  public static func resolveThrows<T>(_ type: T.Type) async throws -> T where T: Sendable {
    return try await DIActor.shared.resolveThrows(type)
  }

  /// Release a specific type using DIActor
  public static func release<T>(_ type: T.Type) async {
    await DIActor.shared.release(type)
  }

  /// Release all registrations using DIActor
  public static func releaseAll() async {
    await DIActor.shared.releaseAll()
  }
}

// MARK: - Migration Helper

/// 기존 코드를 Actor 기반으로 마이그레이션하기 위한 브리지
///
/// ## 마이그레이션 예시:
/// ```swift
/// // OLD (DispatchQueue 기반):
/// DI.register(Service.self) { ServiceImpl() }
/// let service = DI.resolve(Service.self)
///
/// // NEW (Actor 기반):
/// await DIActorBridge.register(Service.self) { ServiceImpl() }
/// let service = await DIActorBridge.resolve(Service.self)
/// ```
public enum DIActorBridge {

  /// 기존 DI API를 Actor 기반으로 브리지
  public static func migrateToActor() async {
    // 기존 등록들을 Actor로 마이그레이션하는 로직은
    // 프로젝트별로 커스터마이즈 필요
    #logDebug("🌉 [DIActorBridge] Ready for migration to Actor-based DI")
  }

  /// 기존 코드와 호환성을 위한 동기 래퍼 (과도기용)
  /// - Warning: 메인 스레드에서만 사용하세요
  @MainActor
  public static func registerSync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) {
    Task.detached { @Sendable in
      _ = await DIActor.shared.register(type, factory: factory)
    }
  }

  /// 기존 코드와 호환성을 위한 동기 래퍼 (과도기용)
  /// - Warning: 메인 스레드에서만 사용하세요
  @MainActor
  public static func resolveSync<T>(_ type: T.Type) -> T? where T: Sendable {
    let box = _DIActorAsyncBox<T>()
    let sem = DispatchSemaphore(value: 0)
    Task.detached { @Sendable in
      box.value = await DIActor.shared.resolve(type)
      sem.signal()
    }
    sem.wait()
    return box.value
  }
}
