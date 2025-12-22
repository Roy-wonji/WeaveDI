//
//  DIContainer.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//  Copyright © 2024 Wonji Suh. All rights reserved.
//

import Foundation
import LogMacro
import Combine

// MARK: - Global Actor

/// DIContainer 전용 Global Actor (자동 정의)
@globalActor
public actor DIContainerActor {
  public static let shared = DIContainerActor()
}

// MARK: - DIContainer

/// ## 개요
///
/// `DIContainer`는 현대적이고 직관적인 의존성 주입 컨테이너입니다.
/// 기존의 여러 Container 클래스들을 하나로 통합하여 단순화했습니다.
///
/// ## 핵심 특징
///
/// ### 🔒 스레드 안전성
/// - **타입 안전한 레지스트리**: TypeSafeRegistry 사용
/// - **동시성 지원**: Swift Concurrency와 완벽 호환
/// - **멀티스레드 안전**: 여러 스레드에서 동시 접근 가능
///
/// ### 📝 통합된 등록 시스템
/// - **즉시 등록**: `register(_:factory:)` - 바로 사용 가능
/// - **인스턴스 등록**: `register(_:instance:)` - 이미 생성된 객체
/// - **KeyPath 지원**: `\.keyPath` 방식으로 타입 안전 보장
/// - **모듈 시스템**: 대량 등록을 위한 Module 패턴
///
/// ### 🚀 부트스트랩 시스템
/// - **안전한 초기화**: 앱 시작 시 의존성 준비
/// - **원자적 교체**: 컨테이너 전체를 한 번에 교체
/// - **테스트 지원**: 테스트 간 격리 보장
/// - **Swift 6 동시성**: 기존 API는 동기, Actor API는 자동 생성
///
/// Invariants for `@unchecked Sendable`:
/// - 모든 공유 상태는 `syncRegistry` 또는 전용 GCD 큐/락을 통해서만 접근한다.
/// - `pendingRegistryTasks` 수정은 `pendingTasksQueue`의 barrier 블록 안에서만 수행한다.
public final class DIContainer: ObservableObject, @unchecked Sendable {

  // MARK: - Properties

  /// 통합된 의존성 저장소 (UnifiedRegistry 기반)
  let unifiedRegistry = UnifiedRegistry.shared

  /// 초고속 동기 접근을 위한 스냅샷 레지스트리 (락 기반)
  let syncRegistry = SyncDependencyRegistry()

  /// UnifiedRegistry 백그라운드 싱크 대기열
  let pendingTasksQueue = DispatchQueue(label: "com.weaveDI.pendingRegistryTasks", attributes: .concurrent)
  var pendingRegistryTasks: [UUID: Task<Void, Never>] = [:]

  /// Parent-Child 관계 지원
  private let parent: DIContainer?
  private var children: [DIContainer] = []
  private let childrenQueue = DispatchQueue(label: "com.diContainer.children", attributes: .concurrent)

  /// Swift 6 완전 호환 shared 인스턴스 관리
  nonisolated(unsafe) private static var sharedContainer = DIContainer()
  private static let sharedLock = NSLock()

  /// 전역 인스턴스 (동기 API - 기존 호환성)
  public static var shared: DIContainer {
    get {
      sharedLock.lock()
      defer { sharedLock.unlock() }
      return sharedContainer
    }
    set {
      sharedLock.lock()
      defer { sharedLock.unlock() }
      sharedContainer = newValue
    }
  }

  // MARK: - Actor Protected API (자동 생성)

  /// @DIContainerActor로 보호된 shared 인스턴스
  @DIContainerActor
  public static var actorShared: DIContainer {
    get { shared }  // 내부적으로 락으로 보호됨
    set { shared = newValue }
  }

  /// Actor 보호하에 의존성 등록
  @DIContainerActor
  public static func registerAsync<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) -> T where T: Sendable {
    return actorShared.register(type, factory: factory)
  }

  /// Actor 보호하에 의존성 해결
  @DIContainerActor
  public static func resolveAsync<T>(_ type: T.Type) -> T? where T: Sendable {
    return actorShared.resolve(type)
  }


  // MARK: - Initialization

  /// 빈 컨테이너를 생성합니다
  /// 기본 초기화 (루트 컨테이너)
  public init() {
    self.parent = nil
  }

  /// Parent-Child 초기화
  /// - Parameter parent: 부모 컨테이너 (의존성을 상속받음)
  public init(parent: DIContainer) {
    self.parent = parent

    // 부모에 자식으로 등록
    parent.childrenQueue.sync(flags: .barrier) {
      parent.children.append(self)
    }
  }

  // MARK: - Parent-Child Container API

  /// 새로운 자식 컨테이너를 생성합니다.
  /// 자식 컨테이너는 부모의 의존성을 상속받습니다.
  ///
  /// ### 사용법:
  /// ```swift
  /// let appContainer = DIContainer()
  /// appContainer.register(DatabaseService.self) { DatabaseImpl() }
  ///
  /// let userModule = appContainer.createChild()
  /// userModule.register(UserRepository.self) {
  ///     UserRepositoryImpl(database: resolve()) // 부모에서 Database 해결
  /// }
  /// ```
  ///
  /// - Returns: 새로운 자식 컨테이너
  public func createChild() -> DIContainer {
    return DIContainer(parent: self)
  }

  /// 모든 자식 컨테이너를 가져옵니다
  /// - Returns: 현재 등록된 자식 컨테이너들
  public func getChildren() -> [DIContainer] {
    return childrenQueue.sync { children }
  }

  /// 부모 컨테이너를 가져옵니다.
  /// - Returns: 부모 컨테이너 (루트인 경우 nil)
  public func getParent() -> DIContainer? {
    return parent
  }


  // MARK: - Core Registration API

  /// 의존성을 등록하고 즉시 생성된 인스턴스를 반환합니다
  ///
  /// 팩토리를 즉시 실행하여 인스턴스를 생성하고, 컨테이너에 등록한 후 반환합니다.
  /// 가장 직관적이고 권장되는 등록 방법입니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 클로저
  /// - Returns: 생성된 인스턴스
  ///
  /// ### 사용 예시:
  /// ```swift
  /// let repository = container.register(UserRepository.self) {
  ///     UserRepositoryImpl()
  /// }
  /// ```
  @discardableResult
  public func registerAsync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) async -> T where T: Sendable {
    registerInstanceSync(type, instance: factory())
  }

  @discardableResult
  public func registerAsync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () async -> T
  ) async -> T where T: Sendable {
    let instance = await factory()
    return registerInstanceSync(type, instance: instance)
  }

  @discardableResult
  public func registerFactoryAsync<T>(
    _ type: T.Type,
    build factory: @escaping @Sendable () -> T
  ) async -> @Sendable () async -> Void where T: Sendable {
    let release = registerFactorySync(type, factory: factory)
    return {
      release()
    }
  }

  public func registerAsync<T>(
    _ type: T.Type,
    instance: T
  ) async where T: Sendable {
    registerInstanceSync(type, instance: instance)
  }

  @discardableResult
  public func register<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) -> T where T: Sendable {
    registerInstanceSync(type, instance: factory())
  }

  /// Actor 격리 컨텍스트에서 의존성을 등록합니다.
  /// 내부적으로 `@DIContainerActor`를 사용하여 Swift 6 동시성 규칙을 준수합니다.
  @discardableResult
  public func actorRegister<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) -> T where T: Sendable {
    registerInstanceSync(type, instance: factory())
  }

  /// 팩토리 패턴으로 의존성을 등록합니다 (지연 생성)
  ///
  /// 실제 `resolve` 호출 시에만 팩토리가 실행되어 매번 새로운 인스턴스가 생성됩니다.
  /// 메모리 효율성이 중요하거나 생성 비용이 높은 경우 사용합니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 클로저
  /// - Returns: 등록 해제 핸들러
  @discardableResult
  public func register<T>(
    _ type: T.Type,
    build factory: @escaping @Sendable () -> T
  ) -> @Sendable () -> Void where T: Sendable {
    registerFactorySync(type, factory: factory)
  }

  /// 이미 생성된 인스턴스를 등록합니다
  ///
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - instance: 등록할 인스턴스
  public func register<T>(
    _ type: T.Type,
    instance: T
  ) where T: Sendable {
    registerInstanceSync(type, instance: instance)
  }

  /// Actor 보호된 인스턴스 등록 (동시성 안전)
  @DIContainerActor
  public func actorRegister<T>(
    _ type: T.Type,
    instance: T
  ) where T: Sendable {
    registerInstanceSync(type, instance: instance)
  }

  // MARK: - Core Resolution API

  /// 등록된 의존성을 조회합니다
  ///
  /// 의존성이 등록되지 않은 경우 nil을 반환하므로 안전하게 처리할 수 있습니다.
  ///
  /// - Parameter type: 조회할 타입
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  public func resolve<T>(_ type: T.Type, logOnMiss: Bool = true) -> T? where T: Sendable {
    OptimizationHooks.trackResolution?(type)

    if let value: T = syncRegistry.resolve(type) {
      if WeaveDIConfiguration.enableVerboseLogging {
        DILogger.debug(channel: .general, "Resolved \(String(describing: type)) from current container")
      }
      return value
    }

    if let parent = parent, let value: T = parent.resolve(type, logOnMiss: logOnMiss) {
      if WeaveDIConfiguration.enableVerboseLogging {
        DILogger.debug(channel: .general, "Resolved \(String(describing: type)) from parent container")
      }
      return value
    }

    if logOnMiss {
      logResolutionMiss(type)
    }
    return nil
  }

  /// 의존성을 조회하거나 기본값을 반환합니다
  ///
  /// - Parameters:
  ///   - type: 조회할 타입
  ///   - defaultValue: 해결 실패 시 사용할 기본값
  /// - Returns: 해결된 인스턴스 또는 기본값
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
  ) -> T where T: Sendable {
    resolve(type) ?? defaultValue()
  }

  /// 특정 타입의 의존성 등록을 해제합니다
  ///
  /// - Parameter type: 해제할 타입
  public func release<T>(_ type: T.Type) where T: Sendable {
    releaseSync(type)
  }

  public func resolveAsync<T>(_ type: T.Type) async -> T? where T: Sendable {
    resolve(type)
  }

  public func releaseAsync<T>(_ type: T.Type) async where T: Sendable {
    releaseSync(type)
  }

  // MARK: - KeyPath Support

  /// KeyPath 기반 의존성 조회 서브스크립트
  ///
  /// - Parameter keyPath: DIContainer의 T?를 가리키는 키패스
  /// - Returns: resolve(T.self) 결과
  public subscript<T>(keyPath: KeyPath<DIContainer, T?>) -> T? where T: Sendable {
    get { resolve(T.self) }
  }

  /// 컨테이너가 비어있는지 확인합니다
  var isEmpty: Bool {
    syncRegistry.isEmpty
  }
}
