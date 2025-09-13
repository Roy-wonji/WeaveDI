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

/// ## 개요
/// 
/// `DependencyContainer`는 Swift 애플리케이션에서 의존성 주입(Dependency Injection)을 
/// 관리하기 위한 스레드 안전한 컨테이너입니다. 이 컨테이너는 타입 기반의 의존성 등록과 
/// 조회를 제공하며, Swift Concurrency와 완벽하게 호환됩니다.
///
/// ## 핵심 특징
///
/// ### 🔒 스레드 안전성
/// - **동시성 큐**: `DispatchQueue(attributes: .concurrent)`를 사용하여 읽기 작업 최적화
/// - **배리어 플래그**: 쓰기 작업 시 `.barrier` 플래그로 스레드 안전성 보장
/// - **다중 스레드 지원**: 여러 스레드에서 동시에 안전하게 접근 가능
///
/// ### 📝 타입 기반 등록 시스템
/// - **키 생성**: `String(describing: Type.self)`를 통한 타입별 고유 키 생성
/// - **팩토리 패턴**: 지연 생성을 통한 메모리 효율성
/// - **인스턴스 등록**: 이미 생성된 객체의 직접 등록 지원
///
/// ### 🚀 생명 주기 관리
/// - **부트스트랩**: 앱 시작 시 의존성 초기화
/// - **런타임 업데이트**: 실행 중 의존성 교체 및 업데이트
/// - **정리**: 메모리 누수 방지를 위한 등록 해제 기능
///
/// ## 기본 사용 방법
///
/// ### 1단계: 부트스트랩
/// ```swift
/// // SwiftUI 앱에서
/// @main
/// struct MyApp: App {
///     init() {
///         Task {
///             await DependencyContainer.bootstrap { container in
///                 // 의존성 등록
///                 container.register(NetworkServiceProtocol.self) {
///                     NetworkService(baseURL: URL(string: "https://api.example.com")!)
///                 }
///                 
///                 container.register(UserRepositoryProtocol.self) {
///                     UserRepository(networkService: container.resolve(NetworkServiceProtocol.self)!)
///                 }
///             }
///         }
///     }
///     
///     var body: some Scene {
///         WindowGroup { ContentView() }
///     }
/// }
/// ```
///
/// ### 2단계: 의존성 등록
/// ```swift
/// // 프로토콜 정의
/// protocol UserRepositoryProtocol {
///     func fetchUser(id: String) async throws -> User
///     func createUser(_ user: User) async throws -> User
/// }
///
/// // 구현체 정의
/// struct UserRepository: UserRepositoryProtocol {
///     private let networkService: NetworkServiceProtocol
///     
///     init(networkService: NetworkServiceProtocol) {
///         self.networkService = networkService
///     }
///     
///     func fetchUser(id: String) async throws -> User {
///         return try await networkService.get("/users/\(id)")
///     }
///     
///     func createUser(_ user: User) async throws -> User {
///         return try await networkService.post("/users", body: user)
///     }
/// }
///
/// // 팩토리 클로저로 등록
/// DependencyContainer.live.register(UserRepositoryProtocol.self) {
///     UserRepository(networkService: /* 다른 의존성 주입 */)
/// }
/// ```
///
/// ### 3단계: 의존성 조회 및 사용
/// ```swift
/// class UserService {
///     private let repository: UserRepositoryProtocol
///     
///     init() {
///         // 컨테이너에서 의존성 조회
///         self.repository = DependencyContainer.live.resolve(UserRepositoryProtocol.self)!
///     }
///     
///     func getUser(id: String) async throws -> User {
///         return try await repository.fetchUser(id: id)
///     }
/// }
///
/// // 또는 기본값과 함께 조회
/// let logger = DependencyContainer.live.resolveOrDefault(
///     LoggerProtocol.self,
///     default: ConsoleLogger()
/// )
/// ```
///
/// ## 고급 사용 패턴
///
/// ### 비동기 초기화가 필요한 의존성
/// ```swift
/// await DependencyContainer.bootstrapAsync { container in
///     // 동기 의존성 먼저 등록
///     container.register(ConfigProtocol.self) { AppConfig() }
///     
///     // 비동기 초기화가 필요한 의존성
///     let database = await Database.initialize()
///     container.register(Database.self, instance: database)
///     
///     let remoteConfig = await RemoteConfigService.loadFromServer()
///     container.register(RemoteConfigService.self, instance: remoteConfig)
/// }
/// ```
///
/// ### 런타임 의존성 교체
/// ```swift
/// // 개발 환경에서 프로덕션 환경으로 전환
/// await DependencyContainer.update { container in
///     container.register(LoggerProtocol.self) { 
///         ProductionLogger() // 기존 ConsoleLogger 교체
///     }
///     
///     container.register(AnalyticsProtocol.self) { 
///         FirebaseAnalytics() // Mock에서 실제 구현체로 교체
///     }
/// }
/// ```
///
/// ### 메모리 관리 및 정리
/// ```swift
/// // 등록 시 해제 핸들러 받기
/// let releaseHandler = DependencyContainer.live.register(TempServiceProtocol.self) {
///     TemporaryService()
/// }
///
/// // 필요 시 특정 의존성 해제
/// releaseHandler() // 직접 해제
/// 
/// // 또는 타입으로 해제
/// DependencyContainer.live.release(TempServiceProtocol.self)
/// ```
///
/// ## 에러 처리 및 디버깅
///
/// ### 등록되지 않은 의존성 처리
/// ```swift
/// // 안전한 조회 (옵셔널 반환)
/// if let service = DependencyContainer.live.resolve(OptionalServiceProtocol.self) {
///     // 서비스가 등록된 경우에만 사용
///     service.doSomething()
/// } else {
///     print("OptionalServiceProtocol이 등록되지 않았습니다")
/// }
///
/// // 기본값과 함께 조회
/// let service = DependencyContainer.live.resolveOrDefault(
///     ServiceProtocol.self,
///     default: DefaultService() // 등록되지 않은 경우 기본 구현체 사용
/// )
/// ```
///
/// ### 부트스트랩 상태 확인
/// ```swift
/// // 부트스트랩 완료 여부 확인
/// let isReady = await DependencyContainer.isBootstrapped
/// if !isReady {
///     print("⚠️ 의존성 컨테이너가 아직 초기화되지 않았습니다")
/// }
///
/// // 부트스트랩 보장 (개발 중 유용)
/// await DependencyContainer.ensureBootstrapped()
/// // 부트스트랩되지 않은 경우 precondition failure로 크래시
/// ```
///
/// ## 테스트 지원
///
/// ### 테스트 환경 설정
/// ```swift
/// class MyServiceTests: XCTestCase {
///     
///     override func setUp() async throws {
///         await super.setUp()
///         
///         // 테스트용 컨테이너 리셋
///         await DependencyContainer.resetForTesting()
///         
///         // 테스트용 Mock 객체 등록
///         await DependencyContainer.bootstrap { container in
///             container.register(NetworkServiceProtocol.self) {
///                 MockNetworkService()
///             }
///             
///             container.register(UserRepositoryProtocol.self) {
///                 MockUserRepository(shouldFail: false)
///             }
///         }
///     }
///     
///     func testUserServiceSuccess() async throws {
///         let service = UserService() // Mock 객체들이 자동 주입됨
///         let user = try await service.getUser(id: "123")
///         XCTAssertEqual(user.id, "123")
///     }
///     
///     func testUserServiceFailure() async throws {
///         // 특정 테스트를 위한 설정 변경
///         await DependencyContainer.update { container in
///             container.register(UserRepositoryProtocol.self) {
///                 MockUserRepository(shouldFail: true)
///             }
///         }
///         
///         let service = UserService()
///         
///         do {
///             _ = try await service.getUser(id: "123")
///             XCTFail("예외가 발생해야 합니다")
///         } catch {
///             XCTAssertTrue(error is UserServiceError)
///         }
///     }
/// }
/// ```
///
/// ## 성능 고려사항
///
/// ### 메모리 효율성
/// - **팩토리 패턴**: 의존성은 실제 필요할 때만 생성됩니다
/// - **약한 참조**: 순환 참조를 방지하기 위해 적절한 곳에서 `weak` 사용
/// - **인스턴스 등록**: 싱글톤 객체는 `register(_:instance:)`로 직접 등록
///
/// ### 동시성 최적화
/// - **읽기 최적화**: 여러 스레드에서 동시 읽기 가능
/// - **쓰기 직렬화**: 배리어 플래그로 쓰기 작업 동기화
/// - **부트스트랩 코디네이터**: Actor를 통한 초기화 과정 관리
///
/// ## 주의사항 및 제한사항
///
/// ### ⚠️ 순환 의존성
/// ```swift
/// // ❌ 피해야 할 패턴
/// container.register(ServiceA.self) { container.resolve(ServiceB.self)! }
/// container.register(ServiceB.self) { container.resolve(ServiceA.self)! }
/// // 이는 런타임에 무한 루프나 데드락을 유발할 수 있습니다
/// ```
///
/// ### ⚠️ 부트스트랩 타이밍
/// ```swift
/// // ❌ 잘못된 사용
/// class SomeClass {
///     init() {
///         // 부트스트랩 완료 전에 resolve 호출 - 위험!
///         self.service = DependencyContainer.live.resolve(ServiceProtocol.self)!
///     }
/// }
///
/// // ✅ 올바른 사용
/// class SomeClass {
///     private let service: ServiceProtocol
///     
///     init(service: ServiceProtocol) {
///         self.service = service
///     }
/// }
/// ```
///
/// ### ⚠️ 스레드 안전성 주의사항
/// - 부트스트랩은 앱 시작 시 한 번만 수행하는 것이 좋습니다
/// - `resetForTesting()`은 DEBUG 빌드에서만 사용하세요
/// - 런타임 업데이트는 필요한 경우에만 신중하게 사용하세요
///
/// ## 관련 API
///
/// - ``ContainerRegister``: 프로퍼티 래퍼 기반 의존성 주입
/// - ``RegisterModule``: 모듈 기반 의존성 등록 헬퍼
/// - ``Container``: 배치 등록을 위한 컨테이너
public final class DependencyContainer: @unchecked Sendable, ObservableObject {

  // MARK: - Stored Properties

  /// 타입 안전한 의존성 저장소입니다.
  /// 기존 String 키 방식 대신 타입 안전한 키를 사용합니다.
  private let typeSafeRegistry = TypeSafeRegistry()

  // NOTE: 동기화는 TypeSafeRegistry가 담당하므로 별도의 GCD 큐는 사용하지 않습니다.

  // MARK: - Init

  /// 빈 컨테이너를 생성합니다.
  public init() {}

  // MARK: - Register

  /// 주어진 타입의 의존성을 팩토리 클로저로 등록합니다.
  ///
  /// 이 메서드는 지연 생성(lazy creation) 패턴을 사용하여 의존성을 등록합니다.
  /// 팩토리 클로저는 실제로 `resolve(_:)` 호출 시에만 실행되어 메모리 효율성을 제공합니다.
  ///
  /// ## 사용 방법
  ///
  /// ### 기본 등록
  /// ```swift
  /// DependencyContainer.live.register(UserServiceProtocol.self) {
  ///     UserService()
  /// }
  /// ```
  ///
  /// ### 다른 의존성을 주입받는 등록
  /// ```swift
  /// DependencyContainer.live.register(UserRepositoryProtocol.self) {
  ///     let networkService = DependencyContainer.live.resolve(NetworkServiceProtocol.self)!
  ///     return UserRepository(networkService: networkService)
  /// }
  /// ```
  ///
  /// ### 복잡한 초기화가 필요한 경우
  /// ```swift
  /// DependencyContainer.live.register(DatabaseProtocol.self) {
  ///     let config = DatabaseConfig(
  ///         url: "sqlite:///app.db",
  ///         poolSize: 10,
  ///         timeout: 30
  ///     )
  ///     return SQLiteDatabase(config: config)
  /// }
  /// ```
  ///
  /// ## 해제 핸들러 사용
  /// ```swift
  /// let releaseHandler = container.register(TempServiceProtocol.self) {
  ///     TemporaryService()
  /// }
  ///
  /// // 나중에 해제 필요 시
  /// releaseHandler()
  /// ```
  ///
  /// - Parameters:
  ///   - type: 등록할 프로토콜 또는 클래스 타입 (예: `AuthRepositoryProtocol.self`)
  ///   - build: 인스턴스를 생성하는 팩토리 클로저. 매 `resolve` 호출마다 실행됩니다.
  /// - Returns: 해당 등록을 해제하는 클로저. 호출 시 의존성이 컨테이너에서 제거됩니다.
  /// 
  /// - Note: 같은 타입을 중복 등록하면 기존 등록을 덮어씁니다.
  /// - Important: 팩토리 클로저는 스레드 안전해야 합니다. 여러 스레드에서 동시에 호출될 수 있습니다.
  /// - Warning: 팩토리 클로저 내에서 같은 타입을 resolve하면 무한 재귀가 발생할 수 있습니다.
  @discardableResult
  public func register<T>(
    _ type: T.Type,
    build: @Sendable @escaping () -> T
  ) -> () -> Void {
    // 타입 안전한 레지스트리 사용
    let releaseHandler = typeSafeRegistry.register(type, factory: build)
    
    Log.debug("Registered (TypeSafe)", String(describing: type))
    
    return releaseHandler
  }

  // MARK: - Resolve

  /// 주어진 타입의 의존성을 조회하여 인스턴스를 반환합니다.
  ///
  /// 이 메서드는 컨테이너에 등록된 팩토리 클로저를 실행하여 인스턴스를 생성합니다.
  /// 팩토리 패턴으로 등록된 경우 매번 새로운 인스턴스가 생성되며,
  /// 인스턴스로 등록된 경우 동일한 객체가 반환됩니다.
  ///
  /// ## 사용 방법
  ///
  /// ### 기본 조회
  /// ```swift
  /// let userService = DependencyContainer.live.resolve(UserServiceProtocol.self)
  /// if let service = userService {
  ///     let user = try await service.getUser(id: "123")
  /// }
  /// ```
  ///
  /// ### 강제 언래핑 (등록이 확실한 경우)
  /// ```swift
  /// let networkService = DependencyContainer.live.resolve(NetworkServiceProtocol.self)!
  /// let response = try await networkService.get("/api/users")
  /// ```
  ///
  /// ### Guard Let 패턴
  /// ```swift
  /// guard let logger = DependencyContainer.live.resolve(LoggerProtocol.self) else {
  ///     print("Logger가 등록되지 않았습니다")
  ///     return
  /// }
  /// logger.info("작업 시작")
  /// ```
  ///
  /// ### 제네릭 타입 조회
  /// ```swift
  /// let dataStore = DependencyContainer.live.resolve(DataStore<User>.self)
  /// let users = try await dataStore?.fetchAll()
  /// ```
  ///
  /// - Parameter type: 조회할 타입의 메타타입 (예: `UserServiceProtocol.self`)
  /// - Returns: 등록된 팩토리가 있으면 해당 타입의 인스턴스, 없으면 `nil`
  /// 
  /// - Note: 
  ///   - 팩토리로 등록된 경우: 매번 새로운 인스턴스 생성
  ///   - 인스턴스로 등록된 경우: 동일한 객체 반환
  ///   - 등록되지 않은 타입: `nil` 반환
  /// - Important: 이 메서드는 스레드 안전합니다. 여러 스레드에서 동시에 호출 가능합니다.
  /// - Warning: 등록되지 않은 타입에 대해 강제 언래핑(`!`) 사용 시 크래시가 발생합니다.
  public func resolve<T>(_ type: T.Type) -> T? {
    // 타입 안전한 레지스트리에서 조회
    if let result = typeSafeRegistry.resolve(type) {
      Log.debug("Resolved (TypeSafe)", String(describing: type))
      return result
    }
    
    Log.error("No registered dependency found for \(String(describing: T.self))")
    return nil
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
    // 타입 안전한 레지스트리에서 해제
    typeSafeRegistry.release(type)
    Log.debug("Released", String(describing: type))
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
    // 타입 안전한 레지스트리에 인스턴스 등록
    typeSafeRegistry.register(type, instance: instance)
    Log.debug("Registered instance (TypeSafe) for", String(describing: type))
  }
}

// MARK: - Live Container

public extension DependencyContainer {
  /// 애플리케이션 전역에서 사용하는 **라이브 컨테이너**입니다.
  ///
  /// Thread-safe live container with proper synchronization
  private static let liveContainerLock = NSLock()
  // Use nonisolated(unsafe) but with proper locking for backward compatibility
  nonisolated(unsafe) private static var _liveContainer = DependencyContainer()
  
  /// Thread-safe access to live container
  static var live: DependencyContainer {
    get {
      liveContainerLock.lock()
      defer { liveContainerLock.unlock() }
      return _liveContainer
    }
    set {
      liveContainerLock.lock()
      defer { liveContainerLock.unlock() }
      _liveContainer = newValue
    }
  }

  /// Thread-safe bootstrap status with proper synchronization
  private static let bootstrapLock = NSLock()
  nonisolated(unsafe) private static var _didBootstrap = false
  
  static var didBootstrap: Bool {
    get {
      bootstrapLock.lock()
      defer { bootstrapLock.unlock() }
      return _didBootstrap
    }
    set {
      bootstrapLock.lock()
      defer { bootstrapLock.unlock() }
      _didBootstrap = newValue
    }
  }

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
