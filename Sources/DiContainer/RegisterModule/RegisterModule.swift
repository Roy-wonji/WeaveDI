//
//  RegisterModule.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation


/// `RegisterModule`은 Repository 및 UseCase 모듈을 생성하고,
/// 의존성을 DI 컨테이너에 등록하는 공통 로직을 제공합니다.
///
/// ## 주요 기능
/// 1. **특정 타입의 `Module` 인스턴스 생성**
///    - [`makeModule(_:factory:)`](#makemoduletypefactory)
/// 2. **프로토콜 타입 기반 `Module` 클로저 생성**
///    - [`makeDependency(_:factory:)`](#makedependencytypefactory)
/// 3. **Repository 자동 주입을 통한 UseCase 생성**
///    - [`makeUseCaseWithRepository(_:repositoryProtocol:repositoryFallback:factory:)`](#makeusecasewithrepository)
/// 4. **DI 컨테이너 조회 또는 기본값 반환**
///    - [`resolveOrDefault(_:default:)`](#resolveordefault)
/// 5. **타입별 기본 인스턴스 반환**
///    - [`defaultInstance(for:fallback:)`](#defaultinstance)
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

  /// 주어진 타입 `T`와 팩토리 클로저를 이용해 `Module` 인스턴스를 생성합니다.
  ///
  /// - Parameters:
  ///   - type: 생성할 의존성의 프로토콜 타입 (예: `AuthRepositoryProtocol.self`)
  ///   - factory: 해당 타입 인스턴스를 생성하는 클로저 (`@Sendable`)
  /// - Returns: DI 컨테이너에 등록할 `Module` 인스턴스
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
  /// - Parameters:
  ///   - protocolType: 등록할 의존성의 프로토콜 타입 (`T.Type`)
  ///   - factory: 인스턴스를 생성하는 클로저 (`U` 타입이지만 `T`로 캐스팅 가능해야 함)
  /// - Returns: `Module`을 생성하는 클로저 (`() -> Module`)
  public func makeDependency<T, U>(
    _ protocolType: T.Type,
    factory: @Sendable @escaping () -> U
  ) -> () -> Module {
    return {
      self.makeDependencyModule(protocolType) {
        guard let dependency = factory() as? T else {
          fatalError("Failed to cast \(U.self) to \(T.self)")
        }
        return dependency
      }
    }
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
  ) -> (() -> Module)? {
      // 1) 우선 resolve
      if let resolved: Repo = DependencyContainer.live.resolve(repositoryProtocol) {
          return makeDependency(useCaseProtocol) { factory(resolved) }
      }
      // 2) fallback
      if let fb = repositoryFallback {
          return makeDependency(useCaseProtocol) { factory(fb()) }
      }
      // 3) 전략 분기
      switch missing {
      case .useNoOp(let provider):
          return makeDependency(useCaseProtocol) { factory(provider()) }
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
  public func makeUseCaseWithRepository<UseCase, Repo: Sendable>(
      _ useCaseProtocol: UseCase.Type,
      repositoryProtocol: Repo.Type,
      repositoryFallback: @autoclosure @escaping @Sendable () -> Repo,
      missing: MissingRepoStrategy<Repo> = .skipRegistration(),
      factory: @Sendable @escaping (Repo) -> UseCase
  ) -> (() -> Module)? {
      return makeUseCaseWithRepositoryOrNil(
          useCaseProtocol,
          repositoryProtocol: repositoryProtocol,
          repositoryFallback: { repositoryFallback() },
          missing: missing,
          factory: factory
      )
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
