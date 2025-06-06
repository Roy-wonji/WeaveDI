//
//  RegisterModule.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation

#if swift(>=5.9)
@available(iOS 17.0, *)
/// `RegisterModule`은 Repository 및 UseCase 모듈을 생성하고, 의존성을 DI 컨테이너에 등록하는 공통 로직을 제공합니다.
/// 이 구조체를 통해 다음 작업을 수행할 수 있습니다:
/// 1. 특정 타입의 `Module` 인스턴스를 생성 (`makeModule(_:factory:)`).
/// 2. 프로토콜 타입을 기반으로 `Module`을 생성하는 클로저 반환 (`makeDependency(_:factory:)`).
/// 3. Repository 의존성을 자동으로 주입받아 UseCase `Module`을 생성 (`makeUseCaseWithRepository(_:repositoryProtocol:repositoryFallback:factory:)`).
/// 4. DI 컨테이너에서 인스턴스를 조회하거나, 기본값을 반환 (`resolveOrDefault(_:default:)`).
/// 5. 타입별 기본 인스턴스(등록된 의존성이 없을 경우 fallback) 반환 (`defaultInstance(for:fallback:)`).
///
/// ## 역할 및 주요 메서드
///
/// ### 1. makeModule(_:factory:)
/// 주어진 타입 `T`와 팩토리 클로저를 이용해, DI 컨테이너에 등록할 `Module`을 생성합니다.
/// ```swift
/// let userModule = registerModule.makeModule(
///     UserServiceProtocol.self,
///     factory: { DefaultUserService() }
/// )
/// // 이후 `container.register(userModule)` 호출 시 UserServiceProtocol ↔ DefaultUserService 연결
/// ```
///
/// - Parameters:
///   - type: 등록할 의존성의 프로토콜 타입 (예: `AuthRepositoryProtocol.self`)
///   - factory: 해당 타입 인스턴스를 생성하는 클로저 (`@Sendable` 지원)
/// - Returns: DI 컨테이너에 등록할 `Module` 인스턴스.
///
/// ### 2. makeDependency(_:factory:)
/// 특정 프로토콜 타입 `T`에 대해, `Module`을 생성하는 클로저를 반환합니다.
/// 반환된 클로저를 호출하면, 내부적으로 `factory()` 결과를 `T`로 캐스팅하여 `Module`을 생성합니다.
/// ```swift
/// let authRepoDependency = registerModule.makeDependency(
///     AuthRepositoryProtocol.self,
///     factory: { DefaultAuthRepository() }
/// )
/// // authRepoDependency() 호출 시 Module(AuthRepositoryProtocol, DefaultAuthRepository())
/// ```
///
/// - Parameters:
///   - protocolType: 등록할 의존성의 프로토콜 타입 (`T.Type`)
///   - factory: 인스턴스를 생성하는 클로저 (`U` 타입이지만 `T`로 캐스팅 가능해야 함)
/// - Returns: `() -> Module` 형태의 클로저. 호출 시 `Module(protocolType, factory: ...)` 반환.
///
/// ### 3. makeUseCaseWithRepository(_:repositoryProtocol:repositoryFallback:factory:)
/// UseCase 모듈 생성 시, 자동으로 Repository 인스턴스를 주입받아 `Module`을 생성하는 클로저를 반환합니다.
/// 내부적으로 `DependencyContainer.live.resolveOrDefault`를 통해 등록된 Repository를 조회하고,
/// 없을 경우 `repositoryFallback()`을 사용합니다.
/// ```swift
/// let authUseCaseDependency = registerModule.makeUseCaseWithRepository(
///     AuthUseCaseProtocol.self,
///     repositoryProtocol: AuthRepositoryProtocol.self,
///     repositoryFallback: DefaultAuthRepository()
/// ) { repo in
///     DefaultAuthUseCase(repository: repo)
/// }
/// // authUseCaseDependency() 호출 시 Module(AuthUseCaseProtocol, DefaultAuthUseCase(repository: resolvedOrFallbackRepo))
/// ```
///
/// - Parameters:
///   - useCaseProtocol: 등록할 UseCase 프로토콜 타입 (`UseCase.Type`)
///   - repositoryProtocol: 주입받을 Repository 프로토콜 타입 (`Repo.Type`)
///   - repositoryFallback: 등록된 Repository가 없을 경우 반환할 기본 인스턴스를 생성하는 `@Sendable @autoclosure` 클로저
///   - factory: 주입된 `Repo` 인스턴스를 사용하여 `UseCase` 인스턴스를 생성하는 클로저
/// - Returns: `() -> Module` 형태의 클로저. 호출 시 `Module(useCaseProtocol, factory: ...)` 반환.
///
/// ### 4. resolveOrDefault(_:default:)
/// DI 컨테이너에서 주어진 타입의 인스턴스를 조회하거나, 없으면 `defaultFactory()` 결과를 반환합니다.
/// ```swift
/// let authRepo: AuthRepositoryProtocol =
///     registerModule.resolveOrDefault(AuthRepositoryProtocol.self, default: DefaultAuthRepository())
/// ```
///
/// - Parameters:
///   - type: 조회할 의존성의 타입 (`T.Type`)
///   - defaultFactory: 의존성이 없을 경우 사용할 기본값을 생성하는 `@autoclosure` 클로저
/// - Returns: 조회된 인스턴스 또는 해당 타입의 기본값.
///
/// ### 5. defaultInstance(for:fallback:)
/// DI 컨테이너에 등록된 인스턴스가 있으면 이를 반환하고, 없으면 `fallback()` 결과를 반환합니다.
/// 내부적으로 `resolveOrDefault(_:default:)`를 호출합니다.
/// ```swift
/// let userService: UserServiceProtocol =
///     registerModule.defaultInstance(for: UserServiceProtocol.self, fallback: DefaultUserService())
/// ```
///
/// - Parameters:
///   - type: 조회할 의존성의 타입 (`T.Type`)
///   - fallback: 등록된 의존성이 없을 경우 사용할 기본 인스턴스를 생성하는 `@Sendable @autoclosure` 클로저
/// - Returns: 해당 타입의 인스턴스.
///
/// ## 예시 전체 흐름
/// 1) Repository 정의
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
///         // AuthRepositoryProtocol ↔ DefaultAuthRepository 연결
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
/// 2) UseCase 정의
/// ```swift
/// import DiContainer
///
/// protocol AuthUseCaseProtocol {
///     func authenticate(user: String, password: String) async -> Bool
/// }
///
/// struct DefaultAuthUseCase: AuthUseCaseProtocol {
///     let repository: AuthRepositoryProtocol
///     init(repository: AuthRepositoryProtocol) {
///         self.repository = repository
///     }
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
/// 3) AppDIContainer 등록 호출
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
/// 4) 앱 초기화 시점 예시
/// ```swift
/// // SwiftUI 예시
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
/// ```swift
/// // UIKit AppDelegate 예시
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

    /// UseCase 모듈 생성 시, 자동으로 Repository 인스턴스를 주입받아 `Module`을 생성하는 클로저를 반환합니다.
    ///
    /// - Parameters:
    ///   - useCaseProtocol: 등록할 UseCase 프로토콜 타입 (`UseCase.Type`)
    ///   - repositoryProtocol: 주입받을 Repository 프로토콜 타입 (`Repo.Type`)
    ///   - repositoryFallback: 등록된 Repository가 없을 경우 반환할 기본 인스턴스를 생성하는 `@Sendable @autoclosure` 클로저
    ///   - factory: 주입된 `Repo` 인스턴스를 사용하여 `UseCase` 인스턴스를 생성하는 클로저
    /// - Returns: `Module`을 생성하는 클로저 (`() -> Module`)
    public func makeUseCaseWithRepository<UseCase, Repo>(
        _ useCaseProtocol: UseCase.Type,
        repositoryProtocol: Repo.Type,
        repositoryFallback: @Sendable @autoclosure @escaping () -> Repo,
        factory: @Sendable @escaping (Repo) -> UseCase
    ) -> () -> Module {
        return makeDependency(useCaseProtocol) {
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
        DependencyContainer.live.resolveOrDefault(type, default: defaultFactory())
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
        resolveOrDefault(type, default: fallback())
    }
}

#else

/// `RegisterModule`은 Repository 및 UseCase 모듈을 생성하고, 의존성을 DI 컨테이너에 등록하는 공통 로직을 제공합니다.
/// 이 구조체를 통해 다음 작업을 수행할 수 있습니다:
/// 1. 특정 타입의 `Module` 인스턴스를 생성 (`makeModule(_:factory:)`).
/// 2. 프로토콜 타입을 기반으로 `Module`을 생성하는 클로저 반환 (`makeDependency(_:factory:)`).
/// 3. Repository 의존성을 자동으로 주입받아 UseCase `Module`을 생성 (`makeUseCaseWithRepository(_:repositoryProtocol:repositoryFallback:factory:)`).
/// 4. DI 컨테이너에서 인스턴스를 조회하거나, 기본값을 반환 (`resolveOrDefault(_:default:)`).
/// 5. 타입별 기본 인스턴스(등록된 의존성이 없을 경우 fallback) 반환 (`defaultInstance(for:fallback:)`).
///
/// ## 사용 예시 (Swift 5.9 미만 / iOS 17.0 미지원)
///
/// 1) Repository 정의
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
/// 2) UseCase 정의
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
/// 3) AppDIContainer 등록 호출
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
/// 4) 앱 초기화 시점 예시 (AppDelegate)
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
public struct RegisterModule {
    // MARK: - 초기화

    /// 기본 생성자
    public init() {}

    // MARK: - Module 생성

    /// 주어진 타입 `T`와 팩토리 클로저를 이용해 `Module` 인스턴스를 생성합니다.
    ///
    /// - Parameters:
    ///   - type: 생성할 의존성의 프로토콜 타입 (예: `AuthRepositoryProtocol.self`)
    ///   - factory: 해당 타입 인스턴스를 생성하는 클로저
    /// - Returns: DI 컨테이너에 등록할 `Module` 인스턴스
    public func makeModule<T>(_ type: T.Type, factory: @escaping () -> T) -> Module {
        Module(type, factory: factory)
    }

    // MARK: - Repository/UseCase 공통 모듈 생성

    /// 내부 헬퍼 메서드. 실제로는 `makeModule(_:factory:)`를 호출하여 `Module`을 생성합니다.
    ///
    /// - Parameters:
    ///   - type: 생성할 의존성의 타입
    ///   - factory: 의존성 인스턴스를 생성하는 클로저
    /// - Returns: 생성된 `Module` 인스턴스
    private func makeDependencyModule<T>(_ type: T.Type, factory: @escaping () -> T) -> Module {
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
    public func makeDependency<T, U>(_ protocolType: T.Type, factory: @escaping () -> U) -> () -> Module {
        return {
            guard let dependency = factory() as? T else {
                fatalError("Failed to cast \(U.self) to \(T.self)")
            }
            return self.makeDependencyModule(protocolType) {
                dependency
            }
        }
    }

    // MARK: - UseCase에 Repository 자동 주입

    /// UseCase 모듈 생성 시, 자동으로 Repository 인스턴스를 주입받아 `Module`을 생성하는 클로저를 반환합니다.
    ///
    /// - Parameters:
    ///   - useCaseProtocol: 등록할 UseCase 프로토콜 타입 (`UseCase.Type`)
    ///   - repositoryProtocol: 주입받을 Repository 프로토콜 타입 (`Repo.Type`)
    ///   - repositoryFallback: 등록된 Repository가 없을 경우 반환할 기본 인스턴스를 생성하는 `@autoclosure` 클로저
    ///   - factory: 주입된 `Repo` 인스턴스를 사용하여 `UseCase` 인스턴스를 생성하는 클로저
    /// - Returns: `Module`을 생성하는 클로저 (`() -> Module`)
    public func makeUseCaseWithRepository<UseCase, Repo>(
        _ useCaseProtocol: UseCase.Type,
        repositoryProtocol: Repo.Type,
        repositoryFallback: @autoclosure @escaping () -> Repo,
        factory: @escaping (Repo) -> UseCase
    ) -> () -> Module {
        return makeDependency(useCaseProtocol) {
            let repo: Repo = self.defaultInstance(for: repositoryProtocol, fallback: repositoryFallback())
            return factory(repo)
        }
    }

    // MARK: - DI연산

    /// DI 컨테이너에서 주어진 타입의 인스턴스를 조회하거나, 없으면 `defaultFactory()` 결과를 반환합니다.
    ///
    /// - Parameters:
    ///   - type: 조회할 의존성의 타입 (`T.Type`)
    ///   - defaultFactory: 의존성이 없을 경우 사용할 기본값을 생성하는 클로저 (`@autoclosure`)
    /// - Returns: 조회된 인스턴스 또는 해당 타입의 기본값
    public func resolveOrDefault<T>(_ type: T.Type, default defaultFactory: @autoclosure @escaping () -> T) -> T {
        DependencyContainer.live.resolveOrDefault(type, default: defaultFactory())
    }

    // MARK: - 기본 인스턴스 반환

    /// 주어진 타입에 대해 DI 컨테이너에 등록된 인스턴스가 있으면 이를 반환하고,
    /// 없으면 `fallback()` 결과를 반환합니다. 내부적으로 `resolveOrDefault(_:default:)`를 호출합니다.
    ///
    /// - Parameters:
    ///   - type: 조회할 의존성의 타입 (`T.Type`)
    ///   - fallback: 등록된 인스턴스가 없을 경우 사용할 기본 인스턴스를 생성하는 `@autoclosure` 클로저
    /// - Returns: 해당 타입의 인스턴스
    public func defaultInstance<T>(for type: T.Type, fallback: @autoclosure @escaping () -> T) -> T {
        resolveOrDefault(type, default: fallback())
    }
}
#endif
