//
//  DIContainer.swift
//  DiContainer
//
//  Created by 서원지 on 6/8/24.
//

import Foundation
import LogMacro
import Combine

// MARK: - DependencyContainer

/// 애플리케이션 전역에서 의존성을 **등록·조회·해제**할 수 있는
/// 스레드-세이프 DI 컨테이너입니다.
///
/// - Note: 내부 레지스트리는 `String(describing: Type.self)`를 키로 사용합니다.
/// - Important: 동시성 안전을 위해 **concurrent `DispatchQueue` + `.barrier`**로
///   쓰기 작업을 직렬화합니다.
/// - SeeAlso: ``register(_:build:)``, ``resolve(_:)``, ``release(_:)``,
///   ``bootstrap(_:)``, ``bootstrapAsync(_:)``, ``bootstrapMixed(sync:async:)``, ``bootstrapIfNeeded(_:)``,
///   ``update(_:)``, ``updateAsync(_:)``, ``resetForTesting()``, ``isBootstrapped``, ``ensureBootstrapped(file:line:)```
///
/// ### 동시성 모델
/// - 읽기: `sync`
/// - 쓰기: `sync(flags: .barrier)` / `async(flags: .barrier)`
///
/// ### 예시
/// 등록 및 조회:
/// ```swift
/// protocol UserRepositoryProtocol { func fetchUser(id: String) -> String }
///
/// struct DefaultUserRepository: UserRepositoryProtocol {
///   func fetchUser(id: String) -> String { "User(\(id))" }
/// }
///
/// // 등록
/// DependencyContainer.live.register(UserRepositoryProtocol.self) {
///   DefaultUserRepository()
/// }
///
/// // 조회
/// let repo: UserRepositoryProtocol? = DependencyContainer.live.resolve(UserRepositoryProtocol.self)
/// print(repo?.fetchUser(id: "123") ?? "nil") // User(123)
/// ```
///
/// 등록 해제:
/// ```swift
/// let release = DependencyContainer.live.register(LoggerProtocol.self) { ConsoleLogger() }
/// release() // 해제
/// ```
///
/// 인스턴스 직접 등록:
/// ```swift
/// let service = NetworkService(baseURL: URL(string: "https://api.example.com")!)
/// DependencyContainer.live.register(NetworkService.self, instance: service)
/// let ns = DependencyContainer.live.resolve(NetworkService.self)!
/// ```
public final class DependencyContainer: @unchecked Sendable, ObservableObject {

  // MARK: - Stored Properties

  /// 등록된 의존성(또는 팩토리 클로저)을 저장하는 딕셔너리입니다.
  /// 키는 `String(describing: Type.self)`입니다.
  private var registry = [String: Any]()

  /// 등록 해제를 위한 핸들러 저장소입니다.
  private var releaseHandlers = [String: () -> Void]()

  /// 읽기/쓰기를 동기화하는 concurrent 큐입니다.
  /// - Important: 쓰기 작업은 `.barrier` 플래그로 보호됩니다.
  private let syncQueue = DispatchQueue(label: "com.diContainer.syncQueue", attributes: .concurrent)

  // MARK: - Init

  /// 빈 컨테이너를 생성합니다.
  public init() {}

  // MARK: - Register

  /// 주어진 타입의 의존성을 **팩토리 클로저**로 등록합니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 타입 (예: `AuthRepositoryProtocol.self`)
  ///   - build: 인스턴스를 생성하는 팩토리 클로저
  /// - Returns: 나중에 호출하면 해당 등록을 해제하는 클로저
  /// - Important: 여러 스레드에서 동시에 등록해도 쓰기가 직렬화됩니다.
  @discardableResult
  public func register<T>(
    _ type: T.Type,
    build: @escaping () -> T
  ) -> () -> Void {
    let key = String(describing: type)

    syncQueue.sync(flags: .barrier) {
      self.registry[key] = build
    }

    Log.debug("Registered", key)

    let releaseHandler: () -> Void = { [weak self] in
      self?.syncQueue.sync(flags: .barrier) {
        self?.registry[key] = nil
        self?.releaseHandlers[key] = nil
      }
      Log.debug("Released", key)
    }

    syncQueue.sync(flags: .barrier) {
      self.releaseHandlers[key] = releaseHandler
    }

    return releaseHandler
  }

  // MARK: - Resolve

  /// 주어진 타입의 의존성을 조회하여 **새 인스턴스**를 생성합니다.
  ///
  /// - Parameter type: 조회할 타입
  /// - Returns: 등록된 팩토리가 있으면 해당 타입의 인스턴스, 없으면 `nil`
  /// - Note: ``register(_:instance:)``로 등록된 경우 **같은 인스턴스**가 반환됩니다.
  public func resolve<T>(_ type: T.Type) -> T? {
    let key = String(describing: type)
    return syncQueue.sync {
      guard let factory = self.registry[key] as? () -> T else {
        Log.error("No registered dependency found for \(String(describing: T.self))")
        return nil
      }
      return factory()
    }
  }

  /// 주어진 타입의 의존성을 조회하거나, 없으면 **기본값**을 반환합니다.
  ///
  /// - Parameters:
  ///   - type: 조회할 타입
  ///   - defaultValue: 없을 때 사용할 기본값(지연 생성)
  /// - Returns: 등록 결과 또는 기본값
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
  ) -> T {
    resolve(type) ?? defaultValue()
  }

  // MARK: - Release

  /// 특정 타입의 의존성 등록을 **해제**합니다.
  ///
  /// - Parameter type: 해제할 타입
  /// - Note: 등록 시 반환된 클로저를 호출한 것과 동일합니다.
  public func release<T>(_ type: T.Type) {
    let key = String(describing: type)
    syncQueue.async(flags: .barrier) {
      self.releaseHandlers[key]?()
    }
  }

  // MARK: - KeyPath-based Access

  /// KeyPath 기반 의존성 조회 서브스크립트입니다.
  ///
  /// - Parameter keyPath: `DependencyContainer`의 `T?`를 가리키는 키패스
  /// - Returns: `resolve(T.self)` 결과
  /// - Important: 내부적으로 타입 기반 레지스트리를 사용하므로
  ///   실제 저장 프로퍼티가 없어도 동작합니다.
  public subscript<T>(keyPath: KeyPath<DependencyContainer, T?>) -> T? {
    get { resolve(T.self) }
  }

  // MARK: - Register Instance

  /// 이미 생성된 **인스턴스**를 등록합니다.
  ///
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - instance: 등록할 인스턴스
  /// - Note: 이후 ``resolve(_:)``는 항상 이 인스턴스를 반환합니다.
  public func register<T>(
    _ type: T.Type,
    instance: T
  ) {
    let key = String(describing: type)
    syncQueue.sync(flags: .barrier) {
      self.registry[key] = { instance }
    }
    Log.debug("Registered instance for", key)
  }
}

// MARK: - Live Container

public extension DependencyContainer {
  /// 애플리케이션 전역에서 사용하는 **라이브 컨테이너**입니다.
  ///
  /// - Important: 부트스트랩 후 교체되며, `nonisolated(unsafe)`로 표시되어 있습니다.
  ///   쓰기 경로는 부트스트랩 로직에서만 이루어지도록 유지하세요.
  nonisolated(unsafe) static var live = DependencyContainer()

  /// 부트스트랩 완료 여부입니다.
  nonisolated(unsafe) static var didBootstrap = false

  /// 부트스트랩 과정을 직렬화하는 **코디네이터 액터**입니다.
  ///
  /// - Note: 외부에 노출되지 않는 내부 구현체입니다.
  private actor BootstrapCoordinator {
    private var didBootstrap = false
    private var liveContainer = DependencyContainer()

    /// 현재 부트스트랩 여부를 반환합니다.
    func isBootstrapped() -> Bool { didBootstrap }

    /// 부트스트랩 플래그를 설정합니다.
    func setBootstrapped(_ value: Bool) { didBootstrap = value }

    /// 현재 라이브 컨테이너를 반환합니다.
    func getLiveContainer() -> DependencyContainer { liveContainer }

    /// 라이브 컨테이너를 교체합니다.
    func setLiveContainer(_ container: DependencyContainer) { liveContainer = container }

    /// 아직 부트스트랩되지 않았다면 동기 구성 클로저로 부트스트랩합니다.
    ///
    /// - Parameter configure: 새 컨테이너를 구성하는 클로저
    /// - Returns: `(성공 여부, 컨테이너)`
    /// - Throws: 구성 중 발생한 오류
    func bootstrapIfNotAlready(
      _ configure: (DependencyContainer) throws -> Void
    ) throws -> (success: Bool, container: DependencyContainer) {
      guard !didBootstrap else { return (false, liveContainer) }
      let container = DependencyContainer()
      try configure(container)
      liveContainer = container
      didBootstrap = true
      return (true, container)
    }

    /// 아직 부트스트랩되지 않았다면 **비동기 구성 클로저**로 부트스트랩합니다.
    ///
    /// - Parameter configure: 새 컨테이너를 비동기 구성하는 클로저
    /// - Returns: `(성공 여부, 컨테이너)`
    /// - Throws: 구성 중 발생한 오류
    func asyncBootstrapIfNotAlready(
      _ configure: @Sendable (DependencyContainer) async throws -> Void
    ) async throws -> (success: Bool, container: DependencyContainer) {
      guard !didBootstrap else { return (false, liveContainer) }
      let container = DependencyContainer()
      try await configure(container)
      liveContainer = container
      didBootstrap = true
      return (true, container)
    }

    /// 테스트를 위해 상태를 리셋합니다. (DEBUG 전용)
    func resetForTesting() {
      #if DEBUG
      didBootstrap = false
      liveContainer = DependencyContainer()
      #endif
    }
  }

  /// 부트스트랩 코디네이터 싱글턴입니다.
  private static let coordinator = BootstrapCoordinator()
}

// MARK: - Bootstrap APIs

public extension DependencyContainer {

  // MARK: - Sync Bootstrap

  /// 앱 시작 시 1회, **동기 의존성**을 등록합니다.
  ///
  /// 부트스트랩이 아직 수행되지 않았다면 새 컨테이너를 생성해 `configure`로 동기 등록을 수행하고,
  /// 성공 시 ``live`` 와 ``didBootstrap`` 를 갱신합니다. 이미 부트스트랩된 경우 동작을 스킵합니다.
  ///
  /// - Parameter configure: 새 컨테이너를 **동기**로 구성하는 클로저.
  ///   동시성 안전을 위해 `@Sendable` 사용을 권장합니다.
  /// - Important: 이 API 자체는 `async`이지만, `configure` 블록은 **동기 등록**만 수행해야 합니다.
  /// - SeeAlso: ``bootstrapAsync(_:)``, ``bootstrapMixed(sync:async:)``, ``bootstrapIfNeeded(_:)``
  ///
  /// ### 예시
  /// ```swift
  /// @main
  /// struct MyApp: App {
  ///   init() {
  ///     Task {
 ///       await DependencyContainer.bootstrap { c in
 ///         c.register(AuthRepositoryProtocol.self) { DefaultAuthRepository() }
 ///         c.register(AuthUseCaseProtocol.self) {
  ///           AuthUseCase(repository: c.resolve(AuthRepositoryProtocol.self)!)
  ///         }
  ///       }
  ///     }
  ///   }
  ///   var body: some Scene { WindowGroup { RootView() } }
  /// }
  /// ```
  static func bootstrap(
    _ configure: @Sendable (DependencyContainer) -> Void
  ) async {
    do {
      let result = try await coordinator.bootstrapIfNotAlready(configure)
      if result.success {
        self.live = result.container
        self.didBootstrap = true
        Log.info("DependencyContainer bootstrapped synchronously")
      } else {
        Log.error("DependencyContainer is already bootstrapped")
      }
    } catch {
      Log.error("DependencyContainer bootstrap failed: \(error)")
      #if DEBUG
      fatalError("DependencyContainer bootstrap failed: \(error)")
      #endif
    }
  }

  // MARK: - Async Bootstrap

  /// 앱 시작 시 1회, **비동기 의존성**까지 포함하여 등록합니다.
  ///
  /// 내부적으로 새 컨테이너를 만들고 `configure`에서 DB 오픈, 원격 설정 로드 등
  /// **비동기 초기화**를 안전하게 수행할 수 있습니다. 완료 후 ``live`` , ``didBootstrap`` 를 갱신합니다.
  /// 이미 부트스트랩된 경우 `false`를 반환합니다.
  ///
  /// - Parameter configure: 새 컨테이너를 **비동기**로 구성하는 클로저.
  /// - Returns: 실제로 부트스트랩이 수행되면 `true`, 이미 되어 있으면 `false`.
  /// - Important: 장시간 I/O가 포함될 수 있는 초기화를 이 API에서 처리하세요.
  /// - SeeAlso: ``bootstrapMixed(sync:async:)``, ``bootstrapIfNeeded(_:)``
  ///
  /// ### 예시
  /// ```swift
  /// Task {
  ///   let didBootstrap = await DependencyContainer.bootstrapAsync { c in
  ///     c.register(AuthRepositoryProtocol.self) { DefaultAuthRepository() }
  ///     let db = await Database.open()
  ///     c.register(Database.self, instance: db)
  ///   }
  ///   assert(didBootstrap == true)
  /// }
  /// ```
  @discardableResult
  static func bootstrapAsync(
    _ configure: @Sendable (DependencyContainer) async throws -> Void
  ) async -> Bool {
    do {
      let startTime = CFAbsoluteTimeGetCurrent()
      Log.info("Starting DependencyContainer async bootstrap...")

      let result = try await coordinator.asyncBootstrapIfNotAlready(configure)

      if result.success {
        self.live = result.container
        self.didBootstrap = true
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        Log.info("DependencyContainer bootstrapped successfully in \(String(format: "%.3f", duration))s")
        return true
      } else {
        Log.error("DependencyContainer is already bootstrapped")
        return false
      }
    } catch {
      Log.error("DependencyContainer bootstrap failed: \(error)")
      #if DEBUG
      fatalError("DependencyContainer bootstrap failed: \(error)")
      #else
      return false
      #endif
    }
  }

  /// 별도의 `Task` 컨텍스트에서 **비동기 부트스트랩**을 수행하는 편의 메서드입니다.
  ///
  /// 완료/실패 로그는 `MainActor`에서 출력됩니다.
  ///
  /// - Parameter configure: 새 컨테이너를 **비동기**로 구성하는 클로저.
  /// - SeeAlso: ``bootstrapAsync(_:)``
  ///
  /// ### 예시
  /// ```swift
  /// DependencyContainer.bootstrapInTask { c in
  ///   c.register(Tracker.self, instance: Tracker.live)
  ///   await Telemetry.bootstrap()
  /// }
  /// ```
  static func bootstrapInTask(
    _ configure: @Sendable @escaping (DependencyContainer) async throws -> Void
  ) {
    Task.detached(priority: .high) {
      let success = await bootstrapAsync(configure)
      if success {
        await MainActor.run { Log.info("DependencyContainer bootstrap completed in background task") }
      } else {
        await MainActor.run { Log.error("DependencyContainer bootstrap failed in background task") }
      }
    }
  }

  /// 이미 부트스트랩되어 있지 **않은 경우에만** 비동기 부트스트랩을 수행합니다.
  ///
  /// - Parameter configure: 새 컨테이너를 **비동기**로 구성하는 클로저.
  /// - Returns: 실제로 부트스트랩이 수행되면 `true`, 이미 되어 있으면 `false`.
  /// - SeeAlso: ``bootstrapAsync(_:)``
  ///
  /// ### 예시
  /// ```swift
  /// Task {
  ///   _ = await DependencyContainer.bootstrapIfNeeded { c in
  ///     c.register(Config.self, instance: .default)
  ///     await Preloader.loadAll()
  ///   }
  /// }
  /// ```
  @discardableResult
  static func bootstrapIfNeeded(
    _ configure: @Sendable (DependencyContainer) async throws -> Void
  ) async -> Bool {
    let needsBootstrap = !(await coordinator.isBootstrapped())
    if needsBootstrap {
      return await bootstrapAsync(configure)
    } else {
      Log.debug("DependencyContainer bootstrap skipped - already initialized")
      return false
    }
  }

  /// 앱 시작 시 **동기 → 비동기** 순서로 의존성을 등록합니다.
  ///
  /// - Parameters:
  ///   - syncConfigure: 즉시 필요한 **동기** 의존성 등록 블록.
  ///   - asyncConfigure: 추가적인 **비동기** 초기화(예: DB/네트워크 등)를 수행하는 블록.
  /// - Important: 이 API는 `@MainActor`에서 호출됩니다. 내부적으로 코디네이터가 경쟁 없이 한 번만 실행하도록 보장합니다.
  /// - SeeAlso: ``bootstrap(_:)``, ``bootstrapAsync(_:)``
  ///
  /// ### 예시
  /// ```swift
  /// Task { @MainActor in
  ///   await DependencyContainer.bootstrapMixed(
  ///     sync: { c in
  ///       c.register(LoggerProtocol.self) { ConsoleLogger() } // 즉시 필요
  ///     },
  ///     async: { c in
  ///       let remote = await RemoteConfigService.load()
  ///       c.register(RemoteConfigService.self, instance: remote)
  ///     }
  ///   )
  /// }
  /// ```
  @MainActor
  static func bootstrapMixed(
    sync syncConfigure: @Sendable (DependencyContainer) -> Void,
    async asyncConfigure: @Sendable  (DependencyContainer) async -> Void
  ) async {
    let wasBootstrapped = await coordinator.isBootstrapped()
    guard !wasBootstrapped else {
      Log.error("DependencyContainer is already bootstrapped")
      return
    }

    do {
      let result = try await coordinator.asyncBootstrapIfNotAlready { container in
        // 1) 동기 등록
        syncConfigure(container)
        Log.debug("Core dependencies registered synchronously")
        // 2) 비동기 등록
        await asyncConfigure(container)
        Log.debug("Extended dependencies registered asynchronously")
      }

      if result.success {
        self.live = result.container
        self.didBootstrap = true
        Log.info("DependencyContainer bootstrapped with mixed dependencies")
      }
    } catch {
      Log.error("DependencyContainer mixed bootstrap failed: \(error)")
      #if DEBUG
      fatalError("DependencyContainer mixed bootstrap failed: \(error)")
      #endif
    }
  }

  // MARK: - Update APIs

  /// 실행 중 **동기**로 컨테이너를 갱신(교체/추가)합니다.
  ///
  /// - Parameter mutate: 컨테이너를 **동기**로 수정하는 블록.
  /// - Important: 호출 전 ``ensureBootstrapped(file:line:)`` 경로를 통해 부트스트랩 보장이 수행됩니다.
  /// - SeeAlso: ``updateAsync(_:)``
  ///
  /// ### 예시
  /// ```swift
  /// await DependencyContainer.update { c in
  ///   c.register(LoggerProtocol.self) { FileLogger() } // 런타임 교체
  /// }
  /// ```
  static func update(
    _ mutate: (DependencyContainer) -> Void
  ) async {
    await ensureBootstrapped()
    mutate(self.live)
    Log.debug("DependencyContainer updated synchronously")
  }

  /// 실행 중 **비동기**로 컨테이너를 갱신(교체/추가)합니다.
  ///
  /// - Parameter mutate: 컨테이너를 **비동기**로 수정하는 블록.
  /// - Important: 호출 전 ``ensureBootstrapped(file:line:)`` 경로를 통해 부트스트랩 보장이 수행됩니다.
  /// - SeeAlso: ``update(_:)``
  ///
  /// ### 예시
  /// ```swift
  /// await DependencyContainer.updateAsync { c in
  ///   let newDB = await Database.open(path: "test.sqlite")
  ///   c.register(Database.self, instance: newDB)
  /// }
  /// ```
  static func updateAsync(
    _ mutate: (DependencyContainer) async -> Void
  ) async {
    await ensureBootstrapped()
    await mutate(self.live)
    Log.debug("DependencyContainer updated asynchronously")
  }

  // MARK: - Utilities

  /// DI 컨테이너 접근 전, **부트스트랩이 완료되었는지**를 보장합니다.
  ///
  /// - Parameters:
  ///   - file: 호출 파일(자동 전달).
  ///   - line: 호출 라인(자동 전달).
  /// - Precondition: 부트스트랩 미완료 시 **개발 빌드에서 크래시**합니다.
  /// - SeeAlso: ``isBootstrapped``
  ///
  /// ### 예시
  /// ```swift
  /// await DependencyContainer.ensureBootstrapped()
  /// let repo = DependencyContainer.live.resolve(AuthRepositoryProtocol.self)
  /// ```
  static func ensureBootstrapped(
    file: StaticString = #fileID,
    line: UInt = #line
  ) async {
    let isBootstrapped = await coordinator.isBootstrapped()
    precondition(
      isBootstrapped,
      "DI not bootstrapped. Call DependencyContainer.bootstrap(...) first.",
      file: file,
      line: line
    )
  }

  /// 현재 **부트스트랩 여부**를 나타냅니다.
  ///
  /// - Returns: 부트스트랩이 완료되었으면 `true`, 아니면 `false`.
  ///
  /// ### 예시
  /// ```swift
  /// let ready = await DependencyContainer.isBootstrapped
  /// if !ready { /* 지연 초기화 처리 */ }
  /// ```
  static var isBootstrapped: Bool {
    get async { await coordinator.isBootstrapped() }
  }

  /// **테스트 전용**: 컨테이너 상태를 리셋합니다. (`DEBUG` 빌드에서만 동작)
  ///
  /// 내부적으로 코디네이터 상태와 ``live`` 컨테이너를 초기화합니다.
  /// 테스트에서 더블/스텁을 재등록할 수 있도록 합니다.
  ///
  /// - SeeAlso: ``register(_:build:)``, ``register(_:instance:)``
  ///
  /// ### 예시
  /// ```swift
  /// #if DEBUG
  /// await DependencyContainer.resetForTesting()
  /// DependencyContainer.live.register(AuthRepositoryProtocol.self) { StubAuthRepository() }
  /// #endif
  /// ```
  static func resetForTesting() async {
    #if DEBUG
    await coordinator.resetForTesting()
    live = DependencyContainer()
    didBootstrap = false
    Log.error("DependencyContainer reset for testing")
    #else
    assertionFailure("resetForTesting() should only be called in DEBUG builds")
    #endif
  }
}
