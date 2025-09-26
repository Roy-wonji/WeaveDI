//
//  AppDIContainer.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation
import LogMacro

// MARK: - AppDIContainer

/// ## 개요
/// 
/// `AppDIContainer`는 애플리케이션 전체의 의존성 주입을 체계적으로 관리하는 
/// 최상위 컨테이너 클래스입니다. Clean Architecture의 각 계층(Repository, UseCase, Service)을 
/// 자동화된 Factory 패턴을 통해 효율적으로 구성하고 관리합니다.
///
/// ## 핵심 철학
///
/// ### 🏗️ 계층화된 아키텍처 지원
/// - **Repository 계층**: 데이터 접근 및 외부 시스템과의 연동
/// - **UseCase 계층**: 비즈니스 로직과 도메인 규칙 캡슐화
/// - **Service 계층**: 애플리케이션 서비스와 UI 지원
/// - **자동 의존성 해결**: 계층 간 의존성이 자동으로 주입됨
///
/// ### 🏭 Factory 기반 모듈화
/// - **RepositoryModuleFactory**: Repository 의존성 일괄 관리
/// - **UseCaseModuleFactory**: UseCase 의존성과 Repository 자동 연동
/// - **확장 가능성**: 새로운 Factory를 쉽게 추가 가능
/// - **타입 안전성**: 컴파일 타임에 의존성 타입 검증
///
/// ### 🔄 생명주기 관리
/// - **지연 초기화**: 실제 필요 시점에 모듈들이 생성됨
/// - **메모리 효율성**: 사용하지 않는 의존성은 생성되지 않음
///
/// ## 아키텍처 다이어그램
///
/// ```
/// ┌─────────────────────────────────────┐
/// │           AppDIContainer            │
/// │                                     │
/// └─────────────────┬───────────────────┘
///                   │
///       ┌───────────┼───────────┐
///       │           │           │
/// ┌─────▼─────┐ ┌───▼────┐ ┌───▼────────┐
/// │Repository │ │UseCase │ │   Other    │
/// │ Factory   │ │Factory │ │ Factories  │
/// └───────────┘ └────────┘ └────────────┘
///       │           │           │
///       └───────────┼───────────┘
///                   │
/// ┌─────────────────▼───────────────────┐
/// │        DependencyContainer.live     │
/// │          (Global Registry)          │
/// └─────────────────────────────────────┘
/// ```
///
/// ## 동작 방식
///
/// ### 1단계: Factory 준비
/// ```swift
/// // @Factory 프로퍼티 래퍼를 통한 자동 주입
/// @Factory(\.repositoryFactory) 
/// var repositoryFactory: RepositoryModuleFactory
/// 
/// @Factory(\.useCaseFactory)
/// var useCaseFactory: UseCaseModuleFactory
/// ```
///
/// ### 2단계: 모듈 등록
/// ```swift
/// await AppDIContainer.shared.registerDefaultDependencies()
/// // 내부적으로:
/// // 1. Repository Factory에서 모든 Repository 모듈 생성
/// // 2. UseCase Factory에서 Repository와 연동된 UseCase 모듈 생성  
/// // 3. 모든 모듈을 병렬로 DependencyContainer.live에 등록
/// ```
///
/// ### 3단계: 의존성 사용
/// ```swift
/// // 어디서든 등록된 의존성 사용 가능
/// let userService = DependencyContainer.live.resolve(UserServiceProtocol.self)
/// ```
///
/// ## 지원 환경 및 호환성
///
/// ### Swift 버전 호환성
/// - **Swift 5.9+ & iOS 17.0+**: Actor 기반 최적화된 구현
/// - **Swift 5.8 & iOS 16.0+**: 호환성 모드로 동일한 기능 제공
/// - **이전 버전**: Fallback 구현으로 핵심 기능 유지
///
/// ### 동시성 지원
/// - **Swift Concurrency**: async/await 패턴 완전 지원
/// - **GCD 호환**: 기존 DispatchQueue 코드와 호환
/// - **Thread Safe**: 모든 작업이 스레드 안전하게 처리
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
///         #logDebug("Loaded user profile: \(await useCase.loadUserProfile().displayName)")
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
/// - 내부 ``Container``가 등록된 모든 모듈을 **병렬로 실행**하여 성능을 최적화합니다.
/// - Factory 패턴을 통해 Repository, UseCase, Scope 계층을 체계적으로 관리합니다.
///
/// ## See Also
/// - ``Container``: 실제 모듈 등록 및 병렬 실행 담당
/// - ``Module``: 모듈 단위 정의
/// - ``Factory``: 자동 주입 프로퍼티 래퍼
/// - ``RepositoryModuleFactory``: Repository 계층 팩토리
/// - ``UseCaseModuleFactory``: UseCase 계층 팩토리
public final actor AppDIContainer {
  // MARK: - 프로퍼티

  /// Repository 계층에서 사용할 모듈(팩토리) 인스턴스를
  /// KeyPath를 통해 자동으로 주입받습니다.
  @Factory(\.repositoryFactory)
  public var repositoryFactory: RepositoryModuleFactory

  /// UseCase 계층에서 사용할 모듈(팩토리) 인스턴스를
  /// KeyPath를 통해 자동으로 주입받습니다.
  @Factory(\.useCaseFactory)
  public var useCaseFactory: UseCaseModuleFactory

  /// DependencyScope 기반 모듈(팩토리) 인스턴스를
  /// KeyPath를 통해 자동으로 주입받습니다.
  @Factory(\.scopeFactory)
  public var scopeFactory: ScopeModuleFactory

  /// 앱 전역에서 사용할 수 있는 싱글턴 인스턴스입니다.
  public static let shared: AppDIContainer = .init()

  /// 외부 생성을 막기 위한 `private init()`.
  private init() {
    // Factory들을 DI 컨테이너에 기본 등록
//    setupDefaultFactories()
  }

  /// 기본 Factory들을 DI 컨테이너에 등록합니다.
  nonisolated private func setupDefaultFactories() {
    // Repository Factory 등록
    DependencyContainer.live.register(RepositoryModuleFactory.self, instance: RepositoryModuleFactory())

    // UseCase Factory 등록
    DependencyContainer.live.register(UseCaseModuleFactory.self, instance: UseCaseModuleFactory())

    // Scope Factory 등록
    DependencyContainer.live.register(ScopeModuleFactory.self, instance: ScopeModuleFactory())

    // 통합 Factory Manager 등록
    DependencyContainer.live.register(ModuleFactoryManager.self, instance: ModuleFactoryManager())
  }

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
  /// - 이후 ``DIContainer/build()`` 를 호출하여 등록된 모듈들의 초기화 로직을 병렬 실행합니다.
  /// - `registerModule.makeDependency(...)`, `makeUseCaseWithRepository(...)` 등을
  ///   활용해 여러 모듈을 한 번에 등록할 수 있습니다.
  public func registerDependencies(
    registerModules: @escaping @Sendable (Container) async -> Void
  ) async {
    // Enable runtime optimization and minimize logging for performance-sensitive builds
    UnifiedDI.configureOptimization(debounceMs: 100, threshold: 10, realTimeUpdate: true)
    UnifiedDI.setAutoOptimization(true)
    UnifiedDI.setLogLevel(.errors)

    // Swift 6 안전성을 위해 Task 내에서 실행
    await withCheckedContinuation { continuation in
      Task {
        await registerModules(container)
        await container {
          // 빈 클로저: callAsFunction() 체이닝을 위해 사용
        }.build()
        continuation.resume()
      }
    }
  }
}
