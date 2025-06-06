//
//  AppDIContainer.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

/// `AppDIContainer`는 애플리케이션 전반에서 의존성 주입(Dependency Injection)을 담당하는 중앙 컨테이너 클래스입니다.
/// 싱글턴 패턴을 활용하여 앱 전체에서 동일한 인스턴스를 참조할 수 있도록 설계되었습니다.
///
/// ## 지원 환경
/// - Swift 5.9 이상, iOS 17.0 이상: `actor`로 구현되어 스레드 안전성을 보장합니다.
/// - 그 외 환경: 동일한 로직을 `final actor`로 구현하여 Swift 5.9 미만 또는 iOS 17 미지원 시에도 사용 가능합니다.
///
/// 내부적으로 `Container`를 사용해 개별 모듈(Module)을 등록하고, `build()` 호출 시 등록된 모든 모듈의 `register()`를 병렬로 실행합니다.
/// 이 과정을 통해 런타임에 의존성 그래프를 구성하고, 앱 전역에서 `DependencyContainer.live.resolve(...)` 를 통해 인스턴스를 꺼내 사용할 수 있습니다.
#if swift(>=5.9)
@available(iOS 17.0, *)
public final actor AppDIContainer {
    // MARK: - 프로퍼티

    /// Repository 계층에서 사용할 모듈(팩토리) 인스턴스를 `FactoryValues` 내에 정의된 경로에서 자동으로 주입받습니다.
    @Factory(\.repositoryFactory)
    public var repositoryFactory: RepositoryModuleFactory

    /// UseCase 계층에서 사용할 모듈(팩토리) 인스턴스를 `FactoryValues` 내에 정의된 경로에서 자동으로 주입받습니다.
    @Factory(\.useCaseFactory)
    public var useCaseFactory: UseCaseModuleFactory

    /// 애플리케이션 전역에서 사용할 수 있는 싱글턴 인스턴스입니다.
    public static let shared: AppDIContainer = .init()

    /// 외부에서 직접 인스턴스를 생성하지 못하도록 생성자를 `private`으로 감춥니다.
    private init() {}

    /// 내부에서 실제 의존성 등록을 수행할 `Container` 인스턴스입니다.
    private let container = Container()

    // MARK: - 메서드

    /// `registerDependencies` 메서드는 비동기 클로저를 받아, 해당 클로저에서 의존성 모듈들을 등록하도록 합니다.
    /// 이후 `container.build()`를 호출하여 등록된 모든 모듈의 `register()`를 병렬로 실행합니다.
    ///
    /// - Parameter registerModules: `Container` 인스턴스를 인자로 받아 비동기적으로 의존성 모듈들을 등록하는 클로저.
    /// - Note: 이 클로저 내부에서 `registerModule.makeDependency(...)` 등을 활용하여 여러 모듈을 한 번에 등록할 수 있습니다.
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

#else
/// `AppDIContainer`는 애플리케이션 전반에서 의존성 주입(Dependency Injection)을 담당하는 중앙 컨테이너 클래스입니다.
/// 싱글턴 패턴을 활용하여 앱 전체에서 동일한 인스턴스를 참조할 수 있도록 설계되었습니다.
///
/// ## 지원 환경
/// - Swift 5.9 미만 또는 iOS 17.0 미만 환경에서 사용할 수 있습니다.
/// - 내부 로직은 Swift 5.9 이상 구현과 동일하게 동작합니다.
///
/// 내부적으로 `Container`를 사용해 개별 모듈(Module)을 등록하고, `build()` 호출 시 등록된 모든 모듈의 `register()`를 병렬로 실행합니다.
/// 앱 전역에서 `DependencyContainer.live.resolve(...)`를 통해 인스턴스를 꺼내 사용할 수 있습니다.
public final actor AppDIContainer {
    // MARK: - 프로퍼티

    /// Repository 계층에서 사용할 모듈(팩토리) 인스턴스를 `FactoryValues` 내에 정의된 경로에서 자동으로 주입받습니다.
    @Factory(\.repositoryFactory)
    public var repositoryFactory: RepositoryModuleFactory

    /// UseCase 계층에서 사용할 모듈(팩토리) 인스턴스를 `FactoryValues` 내에 정의된 경로에서 자동으로 주입받습니다.
    @Factory(\.useCaseFactory)
    public var useCaseFactory: UseCaseModuleFactory

    /// 애플리케이션 전역에서 사용할 수 있는 싱글턴 인스턴스입니다.
    public static let shared: AppDIContainer = .init()

    /// 외부에서 인스턴스를 생성하지 못하도록 생성자를 `private`으로 감춥니다.
    private init() {}

    /// 내부에서 실제 의존성 등록을 수행할 `Container` 인스턴스입니다.
    private let container = Container()

    // MARK: - 메서드

    /// `registerDependencies` 메서드는 비동기 클로저를 받아, 해당 클로저에서 의존성 모듈들을 등록하도록 합니다.
    /// 이후 `container.build()`를 호출하여 등록된 모든 모듈의 `register()`를 비동기적으로 실행합니다.
    ///
    /// - Parameter registerModules: `Container`를 인자로 받아 비동기적으로 의존성 모듈들을 등록하는 클로저.
    /// - Note: 이 클로저 내부에서 `registerModule.makeDependency(...)` 등을 활용하여 여러 모듈을 한 번에 등록할 수 있습니다.
    public func registerDependencies(
        registerModules: @escaping (Container) async -> Void
    ) async {
        // 1. self를 직접 캡처하지 않도록 container를 로컬 상수에 복사합니다.
        let containerCopy = container

        // 2. 전달받은 비동기 클로저를 로컬 containerCopy를 사용하여 실행합니다.
        //    이 시점에 repositoryFactory, useCaseFactory를 통해 모듈 정의를 containerCopy에 추가
        await registerModules(containerCopy)

        // 3. containerCopy에 모듈이 모두 등록되면, 병렬로 각각의 Module.register()를 실행
        await containerCopy {
            // 빈 클로저: callAsFunction() 체이닝을 위해 사용
        }.build()
    }
}
#endif


// MARK: - 사용 예시 코드

/*
--------------------------------------------
 예시 1: 간단한 모듈 등록 및 실행
--------------------------------------------
import Foundation

// 1) Module 프로토콜 정의
public protocol Module {
    /// 비동기적으로 의존성을 등록하는 메서드
    func register() async
}

// 2) Repository 모듈 구현 예시
struct UserRepositoryModule: Module {
    func register() async {
        // 실제 DB나 네트워크 클라이언트를 DI 컨테이너에 등록
        DependencyContainer.live.register(UserRepositoryProtocol.self) { UserRepository() }
    }
}

// 3) UseCase 모듈 구현 예시
struct UserUseCaseModule: Module {
    func register() async {
        // Repository가 이미 등록되었으므로, resolve를 통해 가져와서 UseCase 등록
        let repo: UserRepositoryProtocol = DependencyContainer.live.resolveOrDefault(
            UserRepositoryProtocol.self,
            default: UserRepository()
        )
        DependencyContainer.live.register(UserUseCaseProtocol.self) { UserUseCase(userRepo: repo) }
    }
}

// 4) DI 등록 및 사용 예시
@main
struct MyApp {
    static func main() async {
        // 4-1. 의존성을 등록할 때 사용할 클로저 정의
        let diClosure: (Container) async -> Void = { container in
            // Container에 Repository 모듈 추가
            container.register(UserRepositoryModule())
            // Container에 UseCase 모듈 추가
            container.register(UserUseCaseModule())
        }

        // 4-2. AppDIContainer를 통해 등록 실행
        await AppDIContainer.shared.registerDependencies(registerModules: diClosure)

        // 4-3. 이후 어느 곳에서든 DependencyContainer.live.resolve(...)로 인스턴스를 가져오기
        let useCase: UserUseCaseProtocol = DependencyContainer.live.resolveOrDefault(
            UserUseCaseProtocol.self,
            default: UserUseCase(userRepo: UserRepository())
        )

        // 예: 등록된 UseCase 사용
        let profile = await useCase.loadUserProfile()
        print("Loaded user profile: \(profile.displayName)")
    }
}
*/

/*
--------------------------------------------
 예시 2: RepositoryModuleFactory & UseCaseModuleFactory 확장
--------------------------------------------
import Foundation

// MARK: RepositoryModuleFactory 확장 예시
extension RepositoryModuleFactory {
    /// 기본 Repository 의존성 정의를 설정하는 함수입니다.
    ///
    /// 이 메서드는 `repositoryDefinitions` 배열에 기본 정의를 등록합니다.
    /// - 예시: `AuthRepositoryProtocol` 타입에 대해 `AuthRepository` 인스턴스를 생성합니다.
    public mutating func registerDefaultDefinitions() {
        // `registerModule`을 로컬 변수에 복사하여 self 캡처 방지
        let registerModuleCopy = registerModule
        repositoryDefinitions = {
            return [
                registerModuleCopy.makeDependency(AuthRepositoryProtocol.self) {
                    DefaultAuthRepository()
                }
            ]
        }()
    }
}

// MARK: UseCaseModuleFactory 확장 예시
extension UseCaseModuleFactory {
    /// 기본 UseCase 의존성 정의를 설정하는 함수입니다.
    ///
    /// 이 메서드는 `useCaseDefinitions` 배열에 기본 정의를 등록합니다.
    /// - 예시: `AuthUseCaseProtocol` 타입에 대해 `AuthUseCase` 인스턴스를 생성합니다.
    public var useCaseDefinitions: [() -> Module] {
        return [
            registerModule.makeUseCaseWithRepository(
                AuthUseCaseProtocol.self,
                repositoryProtocol: AuthRepositoryProtocol.self,
                repositoryFallback: DefaultAuthRepository()
            ) { repo in
                AuthUseCase(repository: repo)
            }
        ]
    }
}

// MARK: DI 등록 호출 예시 (AppDelegate 기반)
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 앱 실행 시 DI 컨테이너에 의존성을 등록합니다.
        registerDependencies()
        return true
    }

    /// 의존성 등록 작업을 비동기적으로 수행하는 함수입니다.
    fileprivate func registerDependencies() {
        Task {
            await AppDIContainer.shared.registerDependencies { container in
                // Repository 기본 의존성 등록
                var repoFactory = AppDIContainer.shared.repositoryFactory
                repoFactory.registerDefaultDefinitions()
                await repoFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }
                // UseCase 기본 의존성 등록
                let useCaseFactory = AppDIContainer.shared.useCaseFactory
                await useCaseFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }
            }
        }
    }
}

// MARK: DI 등록 호출 예시 (SwiftUI App 기반)
import SwiftUI
import ComposableArchitecture

@main
struct TestApp: App {
    // UIKit 기반 AppDelegate 연동
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // 앱 초기화 시 DI 컨테이너에 의존성을 등록합니다.
        registerDependencies()
    }

    var body: some Scene {
        WindowGroup {
            // Composable Architecture Store 생성 및 주입
            let store = Store(initialState: AppReducer.State()) {
                AppReducer()
                    ._printChanges()
                    ._printChanges(.actionLabels)
            }
            AppView(store: store)
        }
    }

    /// 비동기적으로 DI 컨테이너에 의존성을 등록하는 함수입니다.
    private func registerDependencies() {
        Task {
            await AppDIContainer.shared.registerDependencies { container in
                // Repository 기본 의존성 등록
                var repoFactory = AppDIContainer.shared.repositoryFactory
                repoFactory.registerDefaultDefinitions()
                await repoFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }
                // UseCase 기본 의존성 등록
                let useCaseFactory = AppDIContainer.shared.useCaseFactory
                await useCaseFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }
            }
        }
    }
}
*/

/*
--------------------------------------------
 예시 3: ContainerResgister 프로퍼티 래퍼 사용
--------------------------------------------
import Foundation

extension DependencyContainer {
    /// `AuthUseCaseProtocol`을 `ContainerResgister`로 조회하는 예시 프로퍼티
    var authUseCase: AuthUseCaseProtocol? {
        ContainerResgister(\.authUseCase).wrappedValue
    }
}

// 사용 예시:
// let authUC: AuthUseCaseProtocol = ContainerResgister(\.authUseCase).wrappedValue
*/

/*
--------------------------------------------
 로그 사용 안내
--------------------------------------------
- 로그 관련 기능은 별도 라이브러리 [LogMacro](https://github.com/Roy-wonji/LogMacro) 문서를 참고하세요.
*/
