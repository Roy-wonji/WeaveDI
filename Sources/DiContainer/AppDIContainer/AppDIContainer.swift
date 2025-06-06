//
//  AppDIContainer.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

/// AppDIContainer는 애플리케이션 전반에서 의존성 주입(Dependency Injection)을 담당하는 중앙 컨테이너 클래스입니다.
/// 싱글턴 패턴을 활용하여 앱 전체에서 동일한 인스턴스를 참조할 수 있도록 설계되었습니다.
#if swift(>=5.9)
@available(iOS 17.0, *)
public final actor AppDIContainer {
    /// Repository 계층에서 사용할 모듈(팩토리) 인스턴스를 자동으로 주입받습니다.
    @Factory(\.repositoryFactory)
    public var repositoryFactory: RepositoryModuleFactory

    /// UseCase 계층에서 사용할 모듈(팩토리) 인스턴스를 자동으로 주입받습니다.
    @Factory(\.useCaseFactory)
    public var useCaseFactory: UseCaseModuleFactory

    /// 애플리케이션 전역에서 사용할 수 있는 싱글턴 인스턴스입니다.
    public static let shared: AppDIContainer = .init()

    /// 외부에서 인스턴스를 생성하지 못하도록 private으로 생성자를 감춥니다.
    private init() {}

    /// 내부에서 실제 의존성 등록을 수행할 Container 인스턴스입니다.
    private let container = Container()

    // MARK: - 메서드

    /// registerDependencies 메서드는 비동기 클로저를 받아, 해당 클로저에서 의존성 모듈들을 등록하도록 합니다.
    /// 이후 container.build()를 호출하여, 등록된 모든 모듈의 register() 메서드를 비동기적으로 실행합니다.
    ///
    /// - Parameter registerModules: Container를 인자로 받아 비동기적으로 의존성 모듈들을 등록하는 클로저.
    /// - Note: 이 클로저는 앱(또는 라이브러리 사용자)이 원하는 의존성 등록 로직을 제공할 수 있도록 합니다.
    public func registerDependencies(
        registerModules: @escaping (Container) async -> Void
    ) async {
        // self를 직접 캡처하지 않도록 container를 로컬 상수에 복사합니다.
        let containerCopy = container

        // 1. 전달받은 비동기 클로저를 로컬 containerCopy를 사용하여 실행합니다.
        //    이 클로저 내부에서 필요한 의존성 모듈들이 containerCopy에 등록됩니다.
        await registerModules(containerCopy)

        // 2. containerCopy에 등록된 모든 모듈의 register()를 비동기적으로 실행합니다.
        //    callAsFunction()을 빈 클로저로 호출한 뒤 build()를 체이닝합니다.
        await containerCopy {
            // 빈 클로저: callAsFunction()를 활용하여 build()를 체이닝하기 위함입니다.
        }.build()
    }
}

#else
public final actor AppDIContainer {
    /// Repository 계층에서 사용할 모듈(팩토리) 인스턴스를 자동으로 주입받습니다.
    @Factory(\.repositoryFactory)
    public var repositoryFactory: RepositoryModuleFactory

    /// UseCase 계층에서 사용할 모듈(팩토리) 인스턴스를 자동으로 주입받습니다.
    @Factory(\.useCaseFactory)
    public var useCaseFactory: UseCaseModuleFactory

    /// 애플리케이션 전역에서 사용할 수 있는 싱글턴 인스턴스입니다.
    public static let shared: AppDIContainer = .init()

    /// 외부에서 인스턴스를 생성하지 못하도록 private으로 생성자를 감춥니다.
    private init() {}

    /// 내부에서 실제 의존성 등록을 수행할 Container 인스턴스입니다.
    private let container = Container()

    // MARK: - 메서드

    /// registerDependencies 메서드는 비동기 클로저를 받아, 해당 클로저에서 의존성 모듈들을 등록하도록 합니다.
    /// 이후 container.build()를 호출하여, 등록된 모든 모듈의 register() 메서드를 비동기적으로 실행합니다.
    ///
    /// - Parameter registerModules: Container를 인자로 받아 비동기적으로 의존성 모듈들을 등록하는 클로저.
    /// - Note: 이 클로저는 앱(또는 라이브러리 사용자)이 원하는 의존성 등록 로직을 제공할 수 있도록 합니다.
    public func registerDependencies(
        registerModules: @escaping (Container) async -> Void
    ) async {
        // self를 직접 캡처하지 않도록 container를 로컬 상수에 복사합니다.
        let containerCopy = container

        // 1. 전달받은 비동기 클로저를 로컬 containerCopy를 사용하여 실행합니다.
        //    이 클로저 내부에서 필요한 의존성 모듈들이 containerCopy에 등록됩니다.
        await registerModules(containerCopy)

        // 2. containerCopy에 등록된 모든 모듈의 register()를 비동기적으로 실행합니다.
        //    callAsFunction()을 빈 클로저로 호출한 뒤 build()를 체이닝합니다.
        await containerCopy {
            // 빈 클로저: callAsFunction()를 활용하여 build()를 체이닝하기 위함입니다.
        }.build()
    }
}
#endif
