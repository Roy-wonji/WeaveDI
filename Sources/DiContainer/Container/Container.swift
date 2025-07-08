//
//  Container.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation
import Combine


/// `Container`는 모듈(Module)들을 등록하고, 등록된 모든 모듈의 `register()` 메서드를 병렬로 실행(build)하는 역할을 하는 Actor입니다.
///
/// - Swift 5.9 이상, iOS 17.0 이상에서 사용할 수 있습니다.
/// - 모듈(Module) 프로토콜을 구현한 타입들의 인스턴스를 `register(_:)` 메서드를 통해 추가할 수 있습니다.
/// - `build()` 메서드를 호출하면, 내부에 저장된 모든 모듈들의 `register()`를 `TaskGroup`을 이용해 병렬로 실행합니다.
public actor Container {
    // MARK: - 저장 프로퍼티

    /// 등록된 모듈(Module) 인스턴스들을 저장하는 내부 배열.
    private var modules: [Module] = []

    // MARK: - 초기화

    /// 기본 초기화 메서드.
    /// - 설명: 인스턴스 생성 시 `modules` 배열은 빈 상태로 시작됩니다.
    public init() {}

    // MARK: - 모듈 등록

    /// 단일 모듈(Module) 인스턴스를 등록합니다.
    ///
    /// - Parameter module: 등록할 모듈 인스턴스 (Module 프로토콜을 준수).
    /// - Returns: 현재 `Container` 인스턴스(Self). 메서드 체이닝(Fluent API) 방식으로 연쇄 호출이 가능합니다.
    @discardableResult
    public func register(_ module: Module) -> Self {
        modules.append(module)
        return self
    }

    /// Trailing closure를 처리할 때 사용되는 메서드입니다.
    ///
    /// - Parameter block: 호출 즉시 실행할 클로저. 이 클로저 내부에서 추가 설정을 수행할 수 있습니다.
    /// - Returns: 현재 `Container` 인스턴스(Self). 메서드 체이닝(Fluent API) 방식으로 연쇄 호출이 가능합니다.
    @discardableResult
    public func callAsFunction(_ block: () -> Void) -> Self {
        block()
        return self
    }

    // MARK: - 빌드(등록 실행)

    /// 등록된 모든 모듈(Module) 인스턴스들의 `register()` 메서드를 `TaskGroup`을 사용해 병렬로 실행합니다.
    ///
    /// - 설명:
    ///   - 내부에 저장된 `modules` 배열의 각 요소에 대해 비동기 태스크를 생성하고, `register()`를 호출합니다.
    ///   - 모든 태스크가 완료될 때까지 대기하므로, 전체 모듈 등록 시간이 단축됩니다.
    public func build() async {
        await withTaskGroup(of: Void.self) { group in
            for module in modules {
                group.addTask {
                    await module.register()
                }
            }
            // 모든 태스크가 완료될 때까지 대기
        }
    }
}


/// `Container`는 모듈(Module)들을 등록하고, 등록된 모든 모듈의 `register()` 메서드를 병렬로 실행(build)하는 역할을 하는 Actor입니다.
///
/// - Swift 5.9 미만 또는 iOS 17.0 미만 환경에서 사용할 수 있습니다.
/// - 모듈(Module) 프로토콜을 구현한 타입들의 인스턴스를 `register(_:)` 메서드를 통해 추가할 수 있습니다.
/// - `build()` 메서드를 호출하면, 내부에 저장된 모든 모듈들의 `register()`를 `TaskGroup`을 이용해 병렬로 실행합니다.


// MARK: - 사용 예시 코드

/*
--------------------------------------------
 예시 1: 간단한 모듈 등록 및 실행
--------------------------------------------
import Foundation

// 1) Module 프로토콜 정의 (예시)
public protocol Module {
    /// 비동기적으로 의존성을 등록하는 메서드
    func register() async
}

// 2) 실제 Module 구현체 예시
struct ExampleModule: Module {
    func register() async {
        // 실제 의존성 등록 로직 (예: DependencyContainer.live.register(...))
        print("ExampleModule registered")
    }
}

// 3) Container 사용 예시
@main
struct MyApp {
    static func main() async {
        // Container 인스턴스 생성
        let container = Container()

        // 1) 모듈 등록 (Fluent API)
        container
            .register(ExampleModule())   // 단일 모듈 등록
            .callAsFunction {             // trailing closure 사용 예시
                // 추가 설정이 필요하면 이곳에 작성
            }

        // 2) build() 호출하여 등록된 모든 모듈들의 register()를 병렬로 실행
        await container.build()

        // 3) 이후 의존성 등록이 완료되었으므로,
        //    실제 어플리케이션 로직에서 DI 컨테이너를 통해 인스턴스를 꺼내 사용 가능
        //    예: let myService: MyServiceProtocol = DependencyContainer.live.resolve(MyServiceProtocol.self)!

        print("All modules have been registered.")
    }
}
*/

/*
--------------------------------------------
 예시 2: 복수 모듈 등록
--------------------------------------------
import Foundation

// Module 프로토콜 정의
public protocol Module {
    func register() async
}

// Repository 모듈
struct UserRepositoryModule: Module {
    func register() async {
        DependencyContainer.live.register(UserRepositoryProtocol.self) {
            UserRepository()
        }
    }
}

// UseCase 모듈
struct UserUseCaseModule: Module {
    func register() async {
        let repo: UserRepositoryProtocol = DependencyContainer.live.resolveOrDefault(
            UserRepositoryProtocol.self,
            default: UserRepository()
        )
        DependencyContainer.live.register(UserUseCaseProtocol.self) {
            UserUseCase(userRepo: repo)
        }
    }
}

// Container 사용 예시
@main
struct MyApp {
    static func main() async {
        let container = Container()

        // Repository 및 UseCase 모듈 등록
        container.register(UserRepositoryModule())
        container.register(UserUseCaseModule())

        // build() 호출 -> 두 모듈의 register() 병렬 실행
        await container.build()

        // 이후부터 DI 컨테이너에서 인스턴스를 꺼내 사용
        let userUseCase: UserUseCaseProtocol = DependencyContainer.live.resolveOrDefault(
            UserUseCaseProtocol.self,
            default: UserUseCase(userRepo: UserRepository())
        )
        let profile = await userUseCase.loadUserProfile()
        print("Loaded user profile: \(profile.displayName)")
    }
}
*/
