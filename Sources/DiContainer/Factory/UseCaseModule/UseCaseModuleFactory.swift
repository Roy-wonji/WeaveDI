//
//  UseCaseModuleFactory.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//


//
//  UseCaseModuleFactory.swift
//  DiContainer
//
//  Created by Roy on 2025/06/06.
//

import Foundation

#if swift(>=5.9)
@available(iOS 17.0, *)
/// `UseCaseModuleFactory`는 `UseCaseModuleFactoryProtocol`을 채택한 구조체로,
/// 애플리케이션에서 Use Case 계층의 모듈 생성 및 등록을 담당합니다.
///
/// - `registerModule`: 의존성 등록 헬퍼 객체(`RegisterModule`)입니다.
///   이 객체를 통해 Use Case 모듈이 필요로 하는 Repository 등 다른 의존성을 DI 컨테이너에 등록할 수 있습니다.
/// - `useCaseDefinitions`: Use Case 모듈을 생성하는 클로저들의 배열입니다.
///   각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
///   기본 구현에서는 빈 배열을 반환하므로, 앱 측에서는 `extension`을 통해 원하는 모듈 정의를 추가하여 재정의해야 합니다.
///
/// ## 사용 예시
///
/// 1) Use Case 프로토콜 및 구현체 작성
/// ```swift
/// import Foundation
///
/// protocol AuthUseCaseProtocol {
///     func authenticate(user: String, password: String) async -> Bool
/// }
///
/// struct DefaultAuthUseCase: AuthUseCaseProtocol {
///     private let repository: AuthRepositoryProtocol
///
///     init(repository: AuthRepositoryProtocol) {
///         self.repository = repository
///     }
///
///     func authenticate(user: String, password: String) async -> Bool {
///         // Repository를 사용하여 인증 로직 수행
///         return await repository.login(user: user, password: password)
///     }
/// }
/// ```
///
/// 2) `UseCaseModuleFactoryProtocol`을 채택하는 팩토리 타입 생성
/// ```swift
/// import DiContainer
///
/// extension UseCaseModuleFactory {
///     /// 기본 Use Case 의존성 정의를 설정합니다.
///     /// 내부에서 `AuthUseCaseProtocol` 타입에 대해 `DefaultAuthUseCase`를 생성하고,
///     /// `AuthRepositoryProtocol`을 자동으로 주입받도록 합니다.
///     public var useCaseDefinitions: [() -> Module] {
///         let helper = registerModule  // self를 직접 캡처하지 않기 위해 복사
///         return [
///             helper.makeUseCaseWithRepository(
///                 AuthUseCaseProtocol.self,              // 주입할 Use Case 프로토콜
///                 repositoryProtocol: AuthRepositoryProtocol.self,  // 주입받을 Repository 프로토콜
///                 repositoryFallback: DefaultAuthRepository()       // Repository가 없을 때 사용할 기본 인스턴스
///             ) { repo in
///                 DefaultAuthUseCase(repository: repo) // Repository가 주입되어 생성된 Use Case 인스턴스
///             }
///         ]
///     }
/// }
/// ```
///
/// 3) `AppDIContainer` 내에서 호출하여 DI 컨테이너에 모든 Use Case 모듈 등록
/// ```swift
/// import DiContainer
///
/// extension AppDIContainer {
///     /// 기본 Use Case 모듈을 DI 컨테이너에 등록합니다.
///     public func registerDefaultUseCaseModules() async {
///         let factoryCopy = self.useCaseFactory  // 값 타입 복사를 통해 캡처 문제 방지
///
///         await registerDependencies { container in
///             // factoryCopy.useCaseDefinitions를 통해 정의된 모든 Module 인스턴스를 순회하며 등록
///             for module in factoryCopy.makeAllModules() {
///                 await container.register(module)
///             }
///         }
///     }
/// }
/// ```
///
/// 4) 실제 앱 초기화 시점 예시 (SwiftUI `@main` 또는 UIKit `AppDelegate`)
/// ```swift
/// // SwiftUI 예시
/// import SwiftUI
///
/// @main
/// struct MyApp: App {
///     init() {
///         Task {
///             await AppDIContainer.shared.registerDefaultUseCaseModules()
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
/// // UIKit 예시 (AppDelegate)
/// import UIKit
///
/// @main
/// class AppDelegate: UIResponder, UIApplicationDelegate {
///     func application(
///         _ application: UIApplication,
///         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
///     ) -> Bool {
///         Task {
///             await AppDIContainer.shared.registerDefaultUseCaseModules()
///         }
///         return true
///     }
/// }
/// ```
public struct UseCaseModuleFactory: UseCaseModuleFactoryProtocol {
    // MARK: - 저장 프로퍼티

    /// 의존성 등록을 담당하는 헬퍼 객체.
    /// Use Case 모듈을 생성할 때 필요한 Repository 등 다른 의존성을 DI 컨테이너에 등록할 수 있습니다.
    public let registerModule = RegisterModule()

    /// Use Case 모듈을 생성하는 클로저들의 배열.
    /// 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
    ///
    /// - Note: 기본 구현에서는 빈 배열을 반환하므로,
    ///   앱에서는 `extension`을 통해 이 배열을 재정의하여 사용해야 합니다.
    public var useCaseDefinitions: [() -> Module] {
        return []
    }

    // MARK: - 초기화

    /// 기본 생성자.
    /// 별도의 인자 없이 인스턴스를 생성할 수 있으며,
    /// 이후 앱 측에서 `extension`을 통해 `useCaseDefinitions`를 재정의할 수 있습니다.
    public init() {}
}

#else

/// `UseCaseModuleFactory`는 `UseCaseModuleFactoryProtocol`을 채택한 구조체로,
/// Use Case 계층의 모듈 생성 및 등록을 담당합니다.
/// 이 구조체는 의존성 등록 헬퍼 객체(`registerModule`)와
/// Use Case 모듈 생성 클로저 배열(`useCaseDefinitions`)을 포함합니다.
/// 기본 구현에서는 `useCaseDefinitions`가 빈 배열을 반환하므로,
/// 앱 측에서는 `extension`을 통해 원하는 모듈 정의를 추가하여 재정의할 수 있습니다.
///
/// ## 사용 예시 (Swift 5.9 미만 / iOS 17.0 미지원)
///
/// 1) Use Case 프로토콜 및 구현체 작성
/// ```swift
/// import Foundation
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
/// ```
///
/// 2) `UseCaseModuleFactoryProtocol`을 채택하는 팩토리 타입 생성
/// ```swift
/// import DiContainer
///
/// extension UseCaseModuleFactory {
///     /// 기본 Use Case 의존성 정의를 설정합니다.
///     public var useCaseDefinitions: [() -> Module] {
///         let helper = registerModule  // 캡처 문제 방지
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
/// 3) `AppDIContainer` 내에서 호출하여 DI 컨테이너에 모든 Use Case 모듈 등록
/// ```swift
/// import DiContainer
///
/// extension AppDIContainer {
///     public func registerDefaultUseCaseModules() async {
///         let factoryCopy = self.useCaseFactory
///
///         await registerDependencies { container in
///             for module in factoryCopy.makeAllModules() {
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
///             await AppDIContainer.shared.registerDefaultUseCaseModules()
///         }
///         return true
///     }
/// }
/// ```
public struct UseCaseModuleFactory: UseCaseModuleFactoryProtocol {
    // MARK: - 저장 프로퍼티

    /// 의존성 등록을 담당하는 헬퍼 객체입니다.
    public let registerModule = RegisterModule()

    /// Use Case 모듈을 생성하는 클로저들의 배열입니다.
    /// 기본 구현에서는 빈 배열을 반환합니다.
    public var useCaseDefinitions: [() -> Module] {
        return []
    }

    // MARK: - 초기화

    /// 기본 생성자입니다.
    public init() {}
}
#endif
