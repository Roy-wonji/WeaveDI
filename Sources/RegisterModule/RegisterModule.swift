//
//  RegisterModule.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation
import LogMacro


/// ## 개요
/// 
/// `RegisterModule`은 Clean Architecture에서 Repository와 UseCase 계층의 의존성을 
/// 체계적으로 관리하기 위한 핵심 헬퍼 구조체입니다. 이 구조체는 복잡한 의존성 그래프를
/// 간단하고 선언적인 방식으로 구성할 수 있도록 도와줍니다.
///
/// ## 핵심 철학
///
/// ### 🏗️ 계층별 분리
/// - **Repository 계층**: 데이터 접근 로직 캡슐화
/// - **UseCase 계층**: 비즈니스 로직과 Repository 조합
/// - **자동 의존성 주입**: UseCase가 필요한 Repository를 자동으로 주입받음
///
/// ### 📦 모듈화된 등록
/// - **타입 안전성**: 컴파일 타임에 의존성 타입 검증
/// - **지연 생성**: 실제 필요 시점에 Module 인스턴스 생성
/// - **Factory 패턴**: 재사용 가능한 의존성 생성 로직
///
/// ### 🔄 유연한 폴백
/// - **기본 구현체**: Repository 미등록 시 fallback 제공
/// - **조건부 등록**: 의존성 상태에 따른 선택적 등록
/// - **테스트 지원**: Mock 객체 쉬운 교체 가능
///
/// ## 주요 기능 개요
///
/// ### 1. 🏭 기본 모듈 생성
/// - **`makeModule(_:factory:)`**: 단순한 타입-팩토리 쌍 모듈 생성
/// - **`makeDependency(_:factory:)`**: 프로토콜 타입 기반 모듈 클로저 생성
///
/// ### 2. 🔗 자동 의존성 주입  
/// - **`makeUseCaseWithRepository(_:repositoryProtocol:repositoryFallback:factory:)`**: UseCase에 Repository 자동 주입
/// - **`makeUseCaseWithRepositoryOrNil(_:repositoryProtocol:repositoryFallback:missing:factory:)`**: 조건부 UseCase 생성
///
/// ### 3. 🔍 의존성 조회 헬퍼
/// - **`resolveOrDefault(_:default:)`**: 안전한 의존성 조회
/// - **`defaultInstance(for:fallback:)`**: 기본 인스턴스 제공
///
/// ## 역할 및 주요 메서드
///
/// ### 1. makeModule(_:factory:)
/// 주어진 타입 `T`와 팩토리 클로저를 이용해, DI 컨테이너에 등록할 `Module`을 생성합니다.
///
/// ```swift
/// let userModule = registerModule.makeModule(
///     UserServiceProtocol.self,
///     factory: { DefaultUserService() }
/// )
/// // 이후 `container.register(userModule)` 호출 시
/// // UserServiceProtocol ↔ DefaultUserService 연결
/// ```
///
/// - Parameters:
///   - type: 등록할 의존성의 프로토콜 타입
///   - factory: 해당 타입 인스턴스를 생성하는 클로저 (`@Sendable` 지원)
/// - Returns: DI 컨테이너에 등록할 `Module` 인스턴스.
///
/// ### 2. makeDependency(_:factory:)
/// 특정 프로토콜 타입 `T`에 대해, `Module`을 생성하는 클로저를 반환합니다.
///
/// ```swift
/// let authRepoDependency = registerModule.makeDependency(
///     AuthRepositoryProtocol.self,
///     factory: { DefaultAuthRepository() }
/// )
/// // authRepoDependency() → Module(AuthRepositoryProtocol, DefaultAuthRepository())
/// ```
///
/// - Parameters:
///   - protocolType: 등록할 의존성의 프로토콜 타입 (`T.Type`)
///   - factory: 인스턴스를 생성하는 클로저 (`U` 타입이지만 `T`로 캐스팅 가능해야 함)
/// - Returns: `() -> Module` 형태의 클로저
///
/// ### 3. makeUseCaseWithRepository(_:repositoryProtocol:repositoryFallback:factory:)
/// UseCase 모듈 생성 시, 자동으로 Repository 인스턴스를 주입받아 `Module`을 생성하는 클로저를 반환합니다.
///
/// 내부적으로 `DependencyContainer.live.resolveOrDefault`를 통해 등록된 Repository를 조회하고,
/// 없을 경우 `repositoryFallback()`을 사용합니다.
///
/// ```swift
/// let authUseCaseDependency = registerModule.makeUseCaseWithRepository(
///     AuthUseCaseProtocol.self,
///     repositoryProtocol: AuthRepositoryProtocol.self,
///     repositoryFallback: DefaultAuthRepository()
/// ) { repo in
///     DefaultAuthUseCase(repository: repo)
/// }
/// // authUseCaseDependency() 호출 시
/// // Module(AuthUseCaseProtocol, DefaultAuthUseCase(repository: resolvedOrFallbackRepo))
/// ```
///
/// - Parameters:
///   - useCaseProtocol: 등록할 UseCase 프로토콜 타입
///   - repositoryProtocol: 주입받을 Repository 프로토콜 타입
///   - repositoryFallback: Repository 미등록 시 사용할 기본 인스턴스 생성 클로저
///   - factory: Repository 인스턴스를 사용하여 UseCase를 생성하는 클로저
/// - Returns: 생성된 `Module` 클로저
///
/// ### 4. resolveOrDefault(_:default:)
/// DI 컨테이너에서 주어진 타입의 인스턴스를 조회하거나, 없으면 `defaultFactory()` 결과를 반환합니다.
///
/// ```swift
/// let authRepo: AuthRepositoryProtocol =
///     registerModule.resolveOrDefault(AuthRepositoryProtocol.self, default: DefaultAuthRepository())
/// ```
///
/// - Parameters:
///   - type: 조회할 의존성 타입 (`T.Type`)
///   - defaultFactory: 의존성이 없을 경우 사용할 기본값 생성 클로저
/// - Returns: 조회된 인스턴스 또는 기본값
///
/// ### 5. defaultInstance(for:fallback:)
/// DI 컨테이너에 등록된 인스턴스가 있으면 반환하고, 없으면 `fallback()` 결과를 반환합니다.
///
/// ```swift
/// let userService: UserServiceProtocol =
///     registerModule.defaultInstance(for: UserServiceProtocol.self, fallback: DefaultUserService())
/// ```
///
/// - Parameters:
///   - type: 조회할 의존성 타입 (`T.Type`)
///   - fallback: 미등록 시 사용할 기본 인스턴스 생성 클로저
/// - Returns: 해당 타입의 인스턴스
///
/// ## 예시 전체 흐름
///
/// ### 1) Repository 정의
/// ```swift
/// import DiContainer
///
/// protocol AuthRepositoryProtocol {
///     func login(user: String, password: String) async -> Bool
/// }
///
/// struct DefaultAuthRepository: AuthRepositoryProtocol {
///     func login(user: String, password: String) async -> Bool {
///         // 네트워크 요청 로직...
///         return true
///     }
/// }
///
/// extension RepositoryModuleFactory {
///     public mutating func registerDefaultDefinitions() {
///         repositoryDefinitions = [
///             registerModule.makeDependency(
///                 AuthRepositoryProtocol.self,
///                 factory: { DefaultAuthRepository() }
///             )
///         ]
///     }
/// }
/// ```
///
/// ### 2) UseCase 정의
/// ```swift
/// import DiContainer
///
/// protocol AuthUseCaseProtocol {
///     func authenticate(user: String, password: String) async -> Bool
/// }
///
/// struct DefaultAuthUseCase: AuthUseCaseProtocol {
///     let repository: AuthRepositoryProtocol
///
///     init(repository: AuthRepositoryProtocol) {
///         self.repository = repository
///     }
///
///     func authenticate(user: String, password: String) async -> Bool {
///         return await repository.login(user: user, password: password)
///     }
/// }
///
/// extension UseCaseModuleFactory {
///     public var useCaseDefinitions: [() -> Module] {
///         let helper = registerModule
///         return [
///             helper.makeUseCaseWithRepository(
///                 AuthUseCaseProtocol.self,
///                 repositoryProtocol: AuthRepositoryProtocol.self,
///                 repositoryFallback: DefaultAuthRepository()
///             ) { repo in
///                 DefaultAuthUseCase(repository: repo)
///             }
///         ]
///     }
/// }
/// ```
///
/// ### 3) AppDIContainer 등록 호출
/// ```swift
/// import DiContainer
///
/// extension AppDIContainer {
///     public func registerDefaultDependencies() async {
///         var repoFactory = repositoryFactory
///         let useCaseFactoryCopy = useCaseFactory
///
///         await registerDependencies { container in
///             // Repository 모듈 등록
///             repoFactory.registerDefaultDefinitions()
///             for module in repoFactory.makeAllModules() {
///                 await container.register(module)
///             }
///
///             // UseCase 모듈 등록
///             for module in useCaseFactoryCopy.makeAllModules() {
///                 await container.register(module)
///             }
///         }
///     }
/// }
/// ```
///
/// ### 4) 앱 초기화 시점 예시
/// #### SwiftUI
/// ```swift
/// import SwiftUI
///
/// @main
/// struct MyApp: App {
///     init() {
///         Task {
///             await AppDIContainer.shared.registerDefaultDependencies()
///         }
///     }
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///         }
///     }
/// }
/// ```
///
/// #### UIKit AppDelegate
/// ```swift
/// import UIKit
///
/// @main
/// class AppDelegate: UIResponder, UIApplicationDelegate {
///     func application(
///         _ application: UIApplication,
///         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
///     ) -> Bool {
///         Task {
///             await AppDIContainer.shared.registerDefaultDependencies()
///         }
///         return true
///     }
/// }
/// ```
public struct RegisterModule: Sendable {
  // MARK: - 초기화

  /// 기본 생성자
  public init() {}

  // MARK: - Module 생성

  /// 타입과 팩토리 클로저로부터 Module 인스턴스를 생성하는 기본 메서드입니다.
  ///
  /// 이 메서드는 가장 단순하고 직접적인 모듈 생성 방법을 제공합니다. 
  /// 주어진 타입에 대한 인스턴스 생성 로직을 캡슐화하여 재사용 가능한 Module로 변환합니다.
  ///
  /// ## 사용 방법
  ///
  /// ### 기본 서비스 등록
  /// ```swift
  /// let loggerModule = registerModule.makeModule(LoggerProtocol.self) {
  ///     ConsoleLogger(level: .info)
  /// }
  /// 
  /// // 컨테이너에 등록
  /// await container.register(loggerModule)
  /// ```
  ///
  /// ### 설정이 필요한 서비스
  /// ```swift
  /// let networkModule = registerModule.makeModule(NetworkServiceProtocol.self) {
  ///     let config = NetworkConfig(
  ///         baseURL: URL(string: "https://api.example.com")!,
  ///         timeout: 30.0,
  ///         retryCount: 3
  ///     )
  ///     return NetworkService(config: config)
  /// }
  /// ```
  ///
  /// ### 복잡한 초기화 로직
  /// ```swift
  /// let databaseModule = registerModule.makeModule(DatabaseProtocol.self) {
  ///     let connectionString = ProcessInfo.processInfo.environment["DB_CONNECTION"] 
  ///                         ?? "sqlite:///default.db"
  ///     
  ///     let database = SQLiteDatabase(connectionString: connectionString)
  ///     database.configure(poolSize: 10, maxConnections: 20)
  ///     
  ///     return database
  /// }
  /// ```
  ///
  /// ## 동작 원리
  /// 
  /// 1. **타입 등록**: 주어진 메타타입 `T.Type`을 Module의 키로 사용
  /// 2. **팩토리 캡슐화**: 전달받은 클로저를 Module 내부에 저장  
  /// 3. **지연 실행**: Module이 실제로 등록될 때 팩토리 클로저 실행
  /// 4. **인스턴스 반환**: 생성된 인스턴스를 DI 컨테이너에 제공
  ///
  /// - Parameters:
  ///   - type: 등록할 의존성의 타입 메타정보 (예: `UserServiceProtocol.self`)
  ///   - factory: 해당 타입의 인스턴스를 생성하는 `@Sendable` 클로저
  /// - Returns: DI 컨테이너에 등록 가능한 `Module` 인스턴스
  /// 
  /// - Note: 팩토리 클로저는 Module 등록 시점이 아닌 실제 인스턴스 요청 시점에 실행됩니다.
  /// - Important: 팩토리 클로저는 `@Sendable`이므로 동시성 안전해야 합니다.
  /// - Warning: 팩토리 내부에서 동일한 타입을 resolve하면 순환 참조가 발생할 수 있습니다.
  public func makeModule<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () -> T
  ) -> Module {
    Module(type, factory: factory)
  }

  // MARK: - Repository/UseCase 공통 모듈 생성

  /// 내부 헬퍼 메서드. 실제로는 `makeModule(_:factory:)`를 호출하여 `Module`을 생성합니다.
  ///
  /// - Parameters:
  ///   - type: 생성할 의존성의 타입
  ///   - factory: 의존성 인스턴스를 생성하는 클로저
  /// - Returns: 생성된 `Module` 인스턴스
  private func makeDependencyModule<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () -> T
  ) -> Module {
    self.makeModule(type, factory: factory)
  }

  // MARK: - 통합 의존성 생성 함수

  /// 특정 프로토콜 타입 `T`에 대해 `Module`을 생성하는 클로저를 반환합니다.
  /// 반환된 클로저를 호출하면, 내부적으로 `factory()` 결과를 `T`로 캐스팅하여 `Module`을 생성합니다.
  ///
  /// ⚠️ **Deprecated**: 이 메서드는 런타임 타입 캐스팅 실패 시 크래시를 발생시킬 수 있습니다.
  /// 대신 `makeTypeSafeDependency`, `makeDependencyImproved`, 또는 `makeDependencyOptional`을 사용하세요.
  ///
  /// - Parameters:
  ///   - protocolType: 등록할 의존성의 프로토콜 타입 (`T.Type`)
  ///   - factory: 인스턴스를 생성하는 클로저 (`U` 타입이지만 `T`로 캐스팅 가능해야 함)
  /// - Returns: `Module`을 생성하는 클로저 (`() -> Module`)
  @available(*, deprecated, message: "Use makeTypeSafeDependency, makeDependencyImproved, or makeDependencyOptional instead")
  public func makeDependency<T, U>(
    _ protocolType: T.Type,
    factory: @Sendable @escaping () -> U
  ) -> @Sendable () -> Module {
    return makeDependencyImproved(protocolType, factory: factory)
  }

  // MARK: - UseCase에 Repository 자동 주입

  /// UseCase 생성 시, 필요한 Repository 인스턴스를 DI 컨테이너에서 자동으로 주입하는 전략.
  ///
  /// - `useNoOp`: Repository가 없고 `repositoryFallback`도 없을 경우, 지정된 no-op 구현을 대신 주입.
  /// - `skipRegistration`: Repository가 없고 `repositoryFallback`도 없을 경우, 해당 UseCase 모듈 등록을 건너뜀.
  ///
  /// 이 전략은 `makeUseCaseWithRepository` 또는 `makeUseCaseWithRepositoryOrNil`의
  /// `missing` 파라미터로 지정할 수 있습니다.
  ///
  /// ```swift
  /// // 예시: 미등록 시 no-op 주입
  /// helper.makeUseCaseWithRepository(
  ///     AuthUseCaseProtocol.self,
  ///     repositoryProtocol: AuthRepositoryProtocol.self,
  ///     missing: .useNoOp { NoOpAuthRepository() }
  /// ) { repo in
  ///     DefaultAuthUseCase(repository: repo)
  /// }
  ///
  /// // 예시: 미등록 시 등록 스킵
  /// helper.makeUseCaseWithRepository(
  ///     AuthUseCaseProtocol.self,
  ///     repositoryProtocol: AuthRepositoryProtocol.self,
  ///     missing: .skipRegistration { print($0) }
  /// ) { repo in
  ///     DefaultAuthUseCase(repository: repo)
  /// }
  /// ```
  public enum MissingRepoStrategy<Repo>: Sendable {
      /// Repository 미등록 시 no-op 인스턴스를 주입.
      /// - Parameter provider: 대체 Repository 인스턴스를 생성하는 클로저.
      case useNoOp(_ provider: @Sendable () -> Repo)

      /// Repository 미등록 시 모듈 등록을 건너뜀.
      /// - Parameter log: 스킵 시 로그를 출력하는 선택적 클로저.
      case skipRegistration(log: (@Sendable (String) -> Void)? = nil)
  }

  /// UseCase 모듈 생성 시, DI 컨테이너에서 Repository 인스턴스를 자동으로 주입하여
  /// `Module`을 생성하고, 필요한 경우 모듈 등록을 건너뛸 수 있는 버전.
  ///
  /// 등록된 Repository가 없을 경우, 다음 순서로 인스턴스를 결정합니다:
  /// 1. DI 컨테이너에 등록된 Repository
  /// 2. `repositoryFallback` 매개변수로 제공된 기본 인스턴스
  /// 3. `missing` 전략에 따른 처리 (`.useNoOp` 또는 `.skipRegistration`)
  ///
  /// - Parameters:
  ///   - useCaseProtocol: 등록할 UseCase 프로토콜 타입.
  ///   - repositoryProtocol: 주입받을 Repository 프로토콜 타입.
  ///   - repositoryFallback: Repository 미등록 시 사용할 기본 인스턴스(선택적).
  ///   - missing: Repository 미등록 시 동작 전략.
  ///   - factory: 주입된 Repository 인스턴스를 사용하여 UseCase를 생성하는 클로저.
  /// - Returns: 생성된 `Module`을 반환하는 클로저, 또는 `.skipRegistration` 전략일 경우 `nil`.
  ///
  /// ```swift
  /// // 예시: no-op 전략
  /// let module = helper.makeUseCaseWithRepositoryOrNil(
  ///     AuthUseCaseProtocol.self,
  ///     repositoryProtocol: AuthRepositoryProtocol.self,
  ///     missing: .useNoOp { NoOpAuthRepository() }
  /// ) { repo in
  ///     DefaultAuthUseCase(repository: repo)
  /// }
  ///
  /// // 예시: 등록 스킵 전략
  /// let module = helper.makeUseCaseWithRepositoryOrNil(
  ///     AuthUseCaseProtocol.self,
  ///     repositoryProtocol: AuthRepositoryProtocol.self,
  ///     missing: .skipRegistration { print($0) }
  /// ) { repo in
  ///     DefaultAuthUseCase(repository: repo)
  /// }
  /// ```
  public func makeUseCaseWithRepositoryOrNil<UseCase, Repo: Sendable>(
      _ useCaseProtocol: UseCase.Type,
      repositoryProtocol: Repo.Type,
      repositoryFallback: (@Sendable () -> Repo)? = nil,
      missing: MissingRepoStrategy<Repo>,
      factory: @Sendable @escaping (Repo) -> UseCase
  ) -> (@Sendable () -> Module)? {
      // 1) 우선 resolve
      if let resolved: Repo = DependencyContainer.live.resolve(repositoryProtocol) {
          return makeDependencyImproved(useCaseProtocol) { factory(resolved) }
      }
      // 2) fallback
      if let fb = repositoryFallback {
          return makeDependencyImproved(useCaseProtocol) { factory(fb()) }
      }
      // 3) 전략 분기
      switch missing {
      case .useNoOp(let provider):
          return makeDependencyImproved(useCaseProtocol) { factory(provider()) }
      case .skipRegistration(let log):
          log?("[DI] Skip \(UseCase.self): missing \(Repo.self) and no fallback.")
          return nil // 등록 스킵
      }
  }

  /// `makeUseCaseWithRepositoryOrNil`의 편의 오버로드 버전.
  ///
  /// `repositoryFallback`을 `@autoclosure`로 받아 값처럼 간결하게 전달할 수 있으며,
  /// 미등록 처리 전략(`missing`) 기본값은 `.skipRegistration()`입니다.
  ///
  /// - Parameters:
  ///   - useCaseProtocol: 등록할 UseCase 프로토콜 타입.
  ///   - repositoryProtocol: 주입받을 Repository 프로토콜 타입.
  ///   - repositoryFallback: Repository 미등록 시 사용할 기본 인스턴스(@autoclosure).
  ///   - missing: 미등록 처리 전략(기본 `.skipRegistration()`).
  ///   - factory: 주입된 Repository 인스턴스를 사용하여 UseCase를 생성하는 클로저.
  /// - Returns: 생성된 `Module`을 반환하는 클로저, 또는 `.skipRegistration` 전략일 경우 `nil`.
  ///
  /// ```swift
  /// // fallback 제공 시
  /// helper.makeUseCaseWithRepository(
  ///     AuthUseCaseProtocol.self,
  ///     repositoryProtocol: AuthRepositoryProtocol.self,
  ///     repositoryFallback: DefaultAuthRepository()
  /// ) { repo in
  ///     DefaultAuthUseCase(repository: repo)
  /// }
  ///
  /// // fallback 없이 no-op 전략
  /// helper.makeUseCaseWithRepository(
  ///     AuthUseCaseProtocol.self,
  ///     repositoryProtocol: AuthRepositoryProtocol.self,
  ///     missing: .useNoOp { NoOpAuthRepository() }
  /// ) { repo in
  ///     DefaultAuthUseCase(repository: repo)
  /// }
  /// ```
  public func makeUseCaseWithRepository<UseCase, Repo>(
    _ useCaseProtocol: UseCase.Type,
    repositoryProtocol: Repo.Type,
    repositoryFallback: @Sendable @autoclosure @escaping () -> Repo,
    factory: @Sendable @escaping (Repo) -> UseCase
  ) -> @Sendable () -> Module {
    return makeDependencyImproved(useCaseProtocol) {
      let repo: Repo = self.defaultInstance(
        for: repositoryProtocol,
        fallback: repositoryFallback()
      )
      return factory(repo)
    }
  }

  // MARK: - DI연산

  /// DI 컨테이너에서 주어진 타입의 인스턴스를 조회하거나, 없으면 `defaultFactory()` 결과를 반환합니다.
  ///
  /// - Parameters:
  ///   - type: 조회할 의존성의 타입 (`T.Type`)
  ///   - defaultFactory: 의존성이 없을 경우 사용할 기본값을 생성하는 `@autoclosure` 클로저
  /// - Returns: 조회된 인스턴스 또는 해당 타입의 기본값
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultFactory: @autoclosure @escaping () -> T
  ) -> T {
    if let resolved: T = DependencyContainer.live.resolve(type) {
      return resolved
    }
    return defaultFactory()
  }

  // MARK: - 기본 인스턴스 반환

  /// 주어진 타입에 대해 DI 컨테이너에 등록된 인스턴스가 있으면 이를 반환하고,
  /// 없으면 `fallback()` 결과를 반환합니다. 내부적으로 `resolveOrDefault(_:default:)`를 호출합니다.
  ///
  /// - Parameters:
  ///   - type: 조회할 의존성의 타입 (`T.Type`)
  ///   - fallback: 등록된 인스턴스가 없을 경우 사용할 기본 인스턴스를 생성하는 `@Sendable @autoclosure` 클로저
  /// - Returns: 해당 타입의 인스턴스
  public func defaultInstance<T>(
    for type: T.Type,
    fallback: @Sendable @autoclosure @escaping () -> T
  ) -> T {
    if let resolved: T = DependencyContainer.live.resolve(type) {
      return resolved
    }
    return fallback()
  }
  
  // MARK: - DependencyScope Integration
  
  /// DependencyScope를 활용한 타입 안전한 의존성 등록을 위한 메서드입니다.
  ///
  /// 이 메서드는 Needle 스타일의 컴파일 타임 검증을 제공하며,
  /// 의존성 스코프를 통해 필요한 의존성과 제공하는 서비스를 명시적으로 정의합니다.
  ///
  /// ## 사용 예시:
  /// ```swift
  /// // 스코프 정의
  /// struct AuthScope: DependencyScope {
  ///   typealias Dependencies = NetworkServiceProtocol
  ///   typealias Provides = AuthRepositoryProtocol
  /// }
  ///
  /// // 스코프 기반 등록
  /// let authModule = registerModule.makeScopedDependency(
  ///   scope: AuthScope.self,
  ///   factory: { AuthRepositoryImpl() }
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - scope: 의존성 스코프 타입
  ///   - factory: 인스턴스를 생성하는 팩토리 클로저
  /// - Returns: 스코프 검증이 포함된 모듈 생성 클로저
  public func makeScopedDependency<Scope: DependencyScope>(
    scope: Scope.Type,
    factory: @Sendable @escaping () -> Scope.Provides
  ) -> @Sendable () -> Module {
    
    return {
      // 스코프 검증 수행
      if !scope.validate() {
        #logDebug("[DI] Warning: Scope validation failed for \(scope)")
      }
      
      return Module(Scope.Provides.self, factory: factory)
    }
  }
  
  /// 여러 스코프를 함께 검증하며 의존성을 등록하는 메서드입니다.
  ///
  /// ## 사용 예시:
  /// ```swift
  /// let modules = registerModule.makeScopedDependencies {
  ///   (NetworkScope.self, { DefaultNetworkService() })
  ///   (AuthScope.self, { AuthRepositoryImpl() })
  ///   (UserScope.self, { UserUseCaseImpl() })
  /// }
  /// ```
  ///
  /// - Parameter builder: 스코프와 팩토리 쌍들을 정의하는 빌더
  /// - Returns: 검증된 모듈들의 배열
  public func makeScopedDependencies<T>(
    @ScopedDependencyBuilder _ builder: () -> T
  ) -> [@Sendable () -> Module] where T: ScopedDependencyConvertible {
    let scopes = builder().toScopedDependencies()
    
    return scopes.map { scopeEntry in
      return {
        // 각 스코프 검증
        if !scopeEntry.validate() {
          #logDebug("[DI] Warning: Scope validation failed for \(scopeEntry.scopeName)")
        }
        
        return scopeEntry.createModule()
      }
    }
  }
  
  /// 스코프 체인을 활용한 계층적 의존성 등록을 위한 메서드입니다.
  ///
  /// 이 메서드는 의존성 간의 계층 구조를 명시적으로 관리하며,
  /// 상위 스코프의 의존성을 하위 스코프에서 자동으로 주입받을 수 있습니다.
  ///
  /// ## 사용 예시:
  /// ```swift
  /// let chainedModule = registerModule.makeScopedChain(
  ///   parent: NetworkScope.self,
  ///   child: UserScope.self
  /// ) { networkService in
  ///   UserRepositoryImpl(networkService: networkService)
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - parent: 상위 스코프 타입
  ///   - child: 하위 스코프 타입
  ///   - factory: 상위 스코프의 Provides를 받아 하위 스코프 인스턴스를 생성하는 팩토리
  /// - Returns: 계층적 의존성이 해결된 모듈 생성 클로저
  public func makeScopedChain<ParentScope: DependencyScope, ChildScope: DependencyScope>(
    parent: ParentScope.Type,
    child: ChildScope.Type,
    factory: @Sendable @escaping (ParentScope.Provides) -> ChildScope.Provides
  ) -> @Sendable () -> Module {
    
    return {
      // 부모 스코프 검증
      if !parent.validate() {
        #logDebug("[DI] Warning: Parent scope validation failed for \(parent)")
      }
      
      // 자식 스코프 검증
      if !child.validate() {
        #logDebug("[DI] Warning: Child scope validation failed for \(child)")
      }
      
      return Module(ChildScope.Provides.self) {
        // 부모 스코프의 의존성을 조회
        let parentDependency: ParentScope.Provides = self.defaultInstance(
          for: ParentScope.Provides.self,
          fallback: {
            fatalError("[DI] Parent dependency \(ParentScope.Provides.self) not found for scope chain")
          }()
        )
        
        return factory(parentDependency)
      }
    }
  }
  
  // MARK: - Same Interface Pattern Support
  
  /// UseCase와 Repository가 같은 인터페이스를 사용하는 패턴을 위한 특화된 메서드입니다.
  /// 
  /// ⚠️ **주의**: 이 메서드는 실제로는 기존 `makeUseCaseWithRepository`와 동일하게 동작합니다.
  /// 같은 인터페이스 패턴에서는 Repository가 먼저 등록되어야 UseCase가 올바르게 동작합니다.
  /// 
  /// ## 올바른 사용 방법:
  /// ```swift
  /// // 1단계: Repository 먼저 등록
  /// var authRepositoryImplModule: () -> Module {
  ///   makeDependencyImproved(AuthInterface.self) {
  ///     AuthRepositoryImpl() // 실제 Repository 구현체
  ///   }
  /// }
  /// 
  /// // 2단계: UseCase 등록 (Repository를 주입받음)
  /// var authUseCaseImplModule: () -> Module {
  ///   makeUseCaseWithSameInterface(
  ///     AuthInterface.self,
  ///     repositoryFallback: DefaultAuthRepositoryImpl(), // 폴백용
  ///     factory: { repo in 
  ///       AuthUseCaseImpl(repository: repo) // UseCase 구현체
  ///     }
  ///   )
  /// }
  /// ```
  /// 
  /// ## 등록 순서:
  /// ```swift
  /// await Container()
  ///   .register(authRepositoryImplModule()) // Repository 먼저
  ///   .register(authUseCaseImplModule())    // UseCase 나중에
  ///   .build()
  /// ```
  /// 
  /// - Parameters:
  ///   - sharedInterface: Repository와 UseCase가 공유하는 인터페이스 타입
  ///   - repositoryFallback: Repository가 등록되지 않은 경우 사용할 기본 구현체
  ///   - factory: Repository 인스턴스를 받아 UseCase를 생성하는 팩토리 클로저
  /// - Returns: UseCase 모듈을 생성하는 클로저
  /// 
  /// - Important: 이 메서드는 기존 `makeUseCaseWithRepository` 방식과 동일한 제한사항이 있습니다.
  ///   같은 타입으로 등록되므로 Repository와 UseCase 중 나중에 등록된 것만 남게 됩니다.
  @available(*, deprecated, message: "Same interface pattern has limitations. Consider using makeUseCaseWithRepository instead.")
  public func makeUseCaseWithSameInterface<Interface>(
    _ sharedInterface: Interface.Type,
    repositoryFallback: @Sendable @autoclosure @escaping () -> Interface,
    factory: @Sendable @escaping (Interface) -> Interface
  ) -> @Sendable () -> Module {
    
    // 실제로는 기존 방식과 동일한 문제점이 있음
    return makeUseCaseWithRepository(
      sharedInterface,
      repositoryProtocol: sharedInterface, 
      repositoryFallback: repositoryFallback(),
      factory: factory
    )
  }
  
  /// 기존 방식 사용을 권장하는 헬퍼 메서드
  /// 
  /// **권장 사용법**: 같은 인터페이스 패턴에서는 기존 `makeUseCaseWithRepository`를 그대로 사용하세요.
  /// 
  /// ## 올바른 패턴:
  /// ```swift
  /// var authUseCaseImplModule: () -> Module {
  ///   makeUseCaseWithRepository(
  ///     AuthInterface.self,                    // UseCase 인터페이스
  ///     repositoryProtocol: AuthInterface.self, // Repository 인터페이스 (같음)
  ///     repositoryFallback: DefaultAuthRepositoryImpl(),
  ///     factory: { repo in 
  ///       AuthUseCaseImpl(repository: repo)
  ///     }
  ///   )
  /// }
  /// ```
  /// 
  /// - Parameters:
  ///   - sharedInterface: 공유하는 인터페이스 타입
  ///   - repositoryFallback: Repository 폴백
  ///   - factory: UseCase 생성 팩토리
  /// - Returns: UseCase 모듈 생성 클로저
  public func makeRecommendedSameInterfaceUseCase<Interface>(
    _ sharedInterface: Interface.Type,
    repositoryFallback: @Sendable @autoclosure @escaping () -> Interface,
    factory: @Sendable @escaping (Interface) -> Interface
  ) -> @Sendable () -> Module {
    
    // 기존 방식 그대로 사용 (가장 안전함)
    return makeUseCaseWithRepository(
      sharedInterface,
      repositoryProtocol: sharedInterface,
      repositoryFallback: repositoryFallback(),
      factory: factory
    )
  }
}



/// `RegisterModule`은 Repository 및 UseCase 모듈을 생성하고,
/// 의존성을 DI 컨테이너에 등록하는 공통 로직을 제공합니다.
///
/// 이 구조체를 통해 다음 작업을 수행할 수 있습니다:
/// 1. 특정 타입의 `Module` 인스턴스를 생성
///    - [`makeModule(_:factory:)`](#makemoduletypefactory)
/// 2. 프로토콜 타입을 기반으로 `Module`을 생성하는 클로저 반환
///    - [`makeDependency(_:factory:)`](#makedependencytypefactory)
/// 3. Repository 의존성을 자동으로 주입받아 UseCase `Module`을 생성
///    - [`makeUseCaseWithRepository(_:repositoryProtocol:repositoryFallback:factory:)`](#makeusecasewithrepository)
/// 4. DI 컨테이너에서 인스턴스를 조회하거나, 기본값을 반환
///    - [`resolveOrDefault(_:default:)`](#resolveordefault)
/// 5. 타입별 기본 인스턴스(등록된 의존성이 없을 경우 fallback) 반환
///    - [`defaultInstance(for:fallback:)`](#defaultinstance)
///
/// ## 사용 예시
///
/// ### 1) Repository 정의
/// ```swift
/// import DiContainer
///
/// protocol AuthRepositoryProtocol {
///     func login(user: String, password: String) -> Bool
/// }
///
/// struct DefaultAuthRepository: AuthRepositoryProtocol {
///     func login(user: String, password: String) -> Bool {
///         // 실제 로그인 로직...
///         return true
///     }
/// }
///
/// extension RepositoryModuleFactory {
///     public mutating func registerDefaultDefinitions() {
///         repositoryDefinitions = [
///             registerModule.makeDependency(
///                 AuthRepositoryProtocol.self,
///                 factory: { DefaultAuthRepository() }
///             )
///         ]
///     }
/// }
/// ```
///
/// ### 2) UseCase 정의
/// ```swift
/// import DiContainer
///
/// protocol AuthUseCaseProtocol {
///     func authenticate(user: String, password: String) -> Bool
/// }
///
/// struct DefaultAuthUseCase: AuthUseCaseProtocol {
///     private let repository: AuthRepositoryProtocol
///
///     init(repository: AuthRepositoryProtocol) {
///         self.repository = repository
///     }
///
///     func authenticate(user: String, password: String) -> Bool {
///         return repository.login(user: user, password: password)
///     }
/// }
///
/// extension UseCaseModuleFactory {
///     public var useCaseDefinitions: [() -> Module] {
///         let helper = registerModule
///         return [
///             helper.makeUseCaseWithRepository(
///                 AuthUseCaseProtocol.self,
///                 repositoryProtocol: AuthRepositoryProtocol.self,
///                 repositoryFallback: DefaultAuthRepository()
///             ) { repo in
///                 DefaultAuthUseCase(repository: repo)
///             }
///         ]
///     }
/// }
/// ```
///
/// ### 3) AppDIContainer 등록 호출
/// ```swift
/// import DiContainer
///
/// extension AppDIContainer {
///     public func registerDefaultDependencies() async {
///         var repoFactory = repositoryFactory
///         let useCaseFactoryCopy = useCaseFactory
///
///         await registerDependencies { container in
///             repoFactory.registerDefaultDefinitions()
///             for module in repoFactory.makeAllModules() {
///                 await container.register(module)
///             }
///
///             for module in useCaseFactoryCopy.makeAllModules() {
///                 await container.register(module)
///             }
///         }
///     }
/// }
/// ```
///
/// ### 4) 앱 초기화 시점 예시 (AppDelegate)
/// ```swift
/// import UIKit
///
/// @main
/// class AppDelegate: UIResponder, UIApplicationDelegate {
///     func application(
///         _ application: UIApplication,
///         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
///     ) -> Bool {
///         Task {
///             await AppDIContainer.shared.registerDefaultDependencies()
///         }
///         return true
///     }
/// }
/// ```
///
/// - Note: Swift 5.9 미만 / iOS 17.0 미지원 환경에서도 동일하게 사용 가능합니다.

// MARK: - Scoped Dependency Builder

/// 스코프 기반 의존성 빌더를 위한 result builder입니다.
@resultBuilder
public struct ScopedDependencyBuilder {
    public static func buildBlock<T: ScopedDependencyConvertible>(_ component: T) -> T {
        component
    }
    
    public static func buildBlock<T1: ScopedDependencyConvertible, T2: ScopedDependencyConvertible>(
        _ c1: T1, _ c2: T2
    ) -> ScopedDependencyTuple<T1, T2> {
        ScopedDependencyTuple(c1, c2)
    }
    
    public static func buildBlock<T1: ScopedDependencyConvertible, T2: ScopedDependencyConvertible, T3: ScopedDependencyConvertible>(
        _ c1: T1, _ c2: T2, _ c3: T3
    ) -> ScopedDependencyTuple3<T1, T2, T3> {
        ScopedDependencyTuple3(c1, c2, c3)
    }
}

// MARK: - Scoped Dependency Convertible

/// 스코프 기반 의존성으로 변환 가능한 타입을 정의하는 프로토콜입니다.
public protocol ScopedDependencyConvertible {
    func toScopedDependencies() -> [ScopedDependencyEntry]
}

/// 개별 스코프 의존성 엔트리입니다.
public struct ScopedDependencyEntry: Sendable {
    public let scopeName: String
    private let validateFunc: @Sendable () -> Bool
    private let createModuleFunc: @Sendable () -> Module
    
    public init<Scope: DependencyScope>(
        scope: Scope.Type,
        factory: @Sendable @escaping () -> Scope.Provides
    ) {
        self.scopeName = String(describing: scope)
        self.validateFunc = { scope.validate() }
        self.createModuleFunc = { Module(Scope.Provides.self, factory: factory) }
    }
    
    public func validate() -> Bool {
        validateFunc()
    }
    
    public func createModule() -> Module {
        createModuleFunc()
    }
}

// MARK: - Tuple Types for Builder

public struct ScopedDependencyTuple<T1: ScopedDependencyConvertible, T2: ScopedDependencyConvertible>: ScopedDependencyConvertible {
    let first: T1
    let second: T2
    
    public init(_ first: T1, _ second: T2) {
        self.first = first
        self.second = second
    }
    
    public func toScopedDependencies() -> [ScopedDependencyEntry] {
        first.toScopedDependencies() + second.toScopedDependencies()
    }
}

public struct ScopedDependencyTuple3<T1: ScopedDependencyConvertible, T2: ScopedDependencyConvertible, T3: ScopedDependencyConvertible>: ScopedDependencyConvertible {
    let first: T1
    let second: T2
    let third: T3
    
    public init(_ first: T1, _ second: T2, _ third: T3) {
        self.first = first
        self.second = second
        self.third = third
    }
    
    public func toScopedDependencies() -> [ScopedDependencyEntry] {
        first.toScopedDependencies() + second.toScopedDependencies() + third.toScopedDependencies()
    }
}

// MARK: - Scope-Factory Tuple Extension

extension ScopedDependencyEntry: ScopedDependencyConvertible {
    public func toScopedDependencies() -> [ScopedDependencyEntry] {
        [self]
    }
}

// MARK: - Convenience Extensions

public extension RegisterModule {
    
    /// 스코프와 팩토리를 쌍으로 생성하는 편의 메서드입니다.
    /// 
    /// ## 사용 예시:
    /// ```swift
    /// let authEntry = registerModule.scopeFactory(
    ///   AuthScope.self,
    ///   factory: { AuthRepositoryImpl() }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - scope: 의존성 스코프 타입
    ///   - factory: 인스턴스 생성 팩토리
    /// - Returns: 스코프 의존성 엔트리
    func scopeFactory<Scope: DependencyScope>(
        _ scope: Scope.Type,
        factory: @Sendable @escaping () -> Scope.Provides
    ) -> ScopedDependencyEntry {
        ScopedDependencyEntry(scope: scope, factory: factory)
    }
}
