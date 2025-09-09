//
//  AppDIContainer.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

// MARK: - AppDIContainer

/// `AppDIContainer`는 애플리케이션 전반에서 **의존성 주입(Dependency Injection)** 을 담당하는
/// 중앙 컨테이너 클래스입니다.
///
/// # Overview
/// - 앱 전역에서 사용되는 **싱글턴(Singleton)** 인스턴스로 제공됩니다.
/// - 내부적으로 ``Container`` 를 통해 `BatchModule` 기반 모듈들을 등록 및 초기화합니다.
/// - `build()` 호출 시 등록된 모듈들의 ``BatchModule/register()`` 를 **병렬 실행**하여
///   런타임 시점에 의존성 그래프를 완성합니다.
/// - 등록된 의존성은 ``DependencyContainer/live`` 를 통해 앱 전역에서 조회할 수 있습니다.
///
/// ## 특징
/// - **중앙 관리**: 모든 모듈 의존성은 `AppDIContainer.shared`를 통해 등록·관리됩니다.
/// - **자동 주입**: ``Factory`` 프로퍼티 래퍼를 활용하여 `FactoryValues` 내 정의된
///   `repositoryFactory`, `useCaseFactory` 등을 자동으로 주입받습니다.
/// - **유연성**: 커스텀 모듈 또는 Factory 확장을 통해 언제든지 새로운 의존성을 추가할 수 있습니다.
///
/// ## 지원 환경
/// - **Swift 5.9 이상, iOS 17.0 이상**:
///   - `actor` 기반으로 구현되어, `Container` 상태(`modules`)가 **thread-safe** 하게 관리됩니다.
/// - **그 외 환경**:
///   - `final actor` 기반 구현으로 동일한 로직을 제공합니다.
///   - Swift 5.9 미만, iOS 17.0 미만 환경에서도 동일하게 동작합니다.
///
/// ## Example
/// ### 기본 사용
/// ```swift
/// @main
/// struct MyApp {
///     static func main() async {
///         await AppDIContainer.shared.registerDependencies { container in
///             // Repository 모듈 등록
///             container.register(UserRepositoryModule())
///
///             // UseCase 모듈 등록
///             container.register(UserUseCaseModule())
///         }
///
///         // 등록된 UseCase 사용
///         let useCase: UserUseCaseProtocol = DependencyContainer.live.resolveOrDefault(
///             UserUseCaseProtocol.self,
///             default: UserUseCase(userRepo: UserRepository())
///         )
///         print("Loaded user profile: \(await useCase.loadUserProfile().displayName)")
///     }
/// }
/// ```
///
/// ### RepositoryModuleFactory & UseCaseModuleFactory 확장
/// ```swift
/// extension RepositoryModuleFactory {
///     public mutating func registerDefaultDefinitions() {
///         let registerModuleCopy = registerModule
///         repositoryDefinitions = [
///             registerModuleCopy.makeDependency(AuthRepositoryProtocol.self) {
///                 DefaultAuthRepository()
///             }
///         ]
///     }
/// }
///
/// extension UseCaseModuleFactory {
///     public var useCaseDefinitions: [() -> Module] {
///         [
///             registerModule.makeUseCaseWithRepository(
///                 AuthUseCaseProtocol.self,
///                 repositoryProtocol: AuthRepositoryProtocol.self,
///                 repositoryFallback: DefaultAuthRepository()
///             ) { repo in
///                 AuthUseCase(repository: repo)
///             }
///         ]
///     }
/// }
/// ```
///
/// ### ContainerResgister 사용
/// ```swift
/// extension DependencyContainer {
///     var authUseCase: AuthUseCaseProtocol? {
///         ContainerResgister(\.authUseCase).wrappedValue
///     }
/// }
///
/// // 사용 예시
/// let authUC: AuthUseCaseProtocol = ContainerResgister(\.authUseCase).wrappedValue
/// ```
///
/// ### SwiftUI 기반 앱에서 DI 적용
/// ```swift
/// @main
/// struct TestApp: App {
///     @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
///
///     init() {
///         registerDependencies()
///     }
///
///     var body: some Scene {
///         WindowGroup {
///             let store = Store(initialState: AppReducer.State()) {
///                 AppReducer()._printChanges()
///             }
///             AppView(store: store)
///         }
///     }
///
///     private func registerDependencies() {
///         Task {
///             await AppDIContainer.shared.registerDependencies { container in
///                 var repoFactory = AppDIContainer.shared.repositoryFactory
///                 repoFactory.registerDefaultDefinitions()
///                 await repoFactory.makeAllModules().asyncForEach { module in
///                     await container.register(module)
///                 }
///
///                 let useCaseFactory = AppDIContainer.shared.useCaseFactory
///                 await useCaseFactory.makeAllModules().asyncForEach { module in
///                     await container.register(module)
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Discussion
/// - `AppDIContainer`는 단일 진입점(single entry point) 역할을 합니다.
/// - 앱 초기화 시점에 모듈을 한꺼번에 등록해두면, 런타임에서 빠르고 안정적으로
///   의존성 객체를 생성·조회할 수 있습니다.
/// - 모듈 등록 순서가 중요한 경우에는 ``BatchModule/batch`` 값을 활용하여
///   **우선순위 기반 순차 실행**을 보장할 수 있습니다.
///
/// ## See Also
/// - ``Container``: 실제 모듈 등록 및 병렬 실행 담당
/// - ``BatchModule``: 모듈 단위 정의
/// - ``Factory``: 자동 주입 프로퍼티 래퍼
/// - ``ContainerResgister``: 전역 DI 조회 프로퍼티 래퍼
public final actor AppDIContainer {
  // MARK: - 프로퍼티

  /// Repository 계층에서 사용할 모듈(팩토리) 인스턴스를
  /// ``FactoryValues`` 내 정의된 경로에서 자동으로 주입받습니다.
  @Factory(\.repositoryFactory)
  public var repositoryFactory: RepositoryModuleFactory

  /// UseCase 계층에서 사용할 모듈(팩토리) 인스턴스를
  /// ``FactoryValues`` 내 정의된 경로에서 자동으로 주입받습니다.
  @Factory(\.useCaseFactory)
  public var useCaseFactory: UseCaseModuleFactory

  /// 앱 전역에서 사용할 수 있는 싱글턴 인스턴스입니다.
  public static let shared: AppDIContainer = .init()

  /// 외부 생성을 막기 위한 `private init()`.
  private init() {}

  /// 내부적으로 모듈 등록과 빌드를 수행하는 ``Container`` 인스턴스입니다.
  private let container = Container()

  // MARK: - 메서드

  /// 의존성 모듈들을 등록하고, 등록된 모듈을 병렬 실행하여 빌드합니다.
  ///
  /// - Parameter registerModules: ``Container`` 를 인자로 받아
  ///   비동기적으로 모듈을 등록하는 클로저
  /// - Throws: 모듈 초기화 중 발생한 오류
  ///
  /// ### Discussion
  /// - 전달된 클로저에서 `container.register(...)` 메서드를 통해 모듈들을 등록합니다.
  /// - 이후 ``Container/build()`` 를 호출하여 등록된 모듈들의 초기화 로직을 병렬 실행합니다.
  /// - `registerModule.makeDependency(...)`, `makeUseCaseWithRepository(...)` 등을
  ///   활용해 여러 모듈을 한 번에 등록할 수 있습니다.
  public func registerDependencies(
    registerModules: @escaping (Container) async -> Void
  ) async {
    // 1. self를 직접 캡처하지 않도록 container를 로컬 상수에 복사
    let containerCopy = container

    // 2. 전달받은 비동기 클로저를 로컬 containerCopy를 통해 실행
    //    이 시점에 repositoryFactory, useCaseFactory를 통해 모듈 정의를 containerCopy에 추가
    await registerModules(containerCopy)

    // 3. containerCopy에 모듈이 모두 등록되면, 병렬로 각각의 Module.register()를 실행
    await containerCopy {
      // 빈 클로저: callAsFunction() 체이닝을 위해 사용
    }.build()
  }
}
