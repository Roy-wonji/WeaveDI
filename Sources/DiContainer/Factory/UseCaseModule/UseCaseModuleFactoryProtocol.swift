//
//  UseCaseModuleFactoryProtocol.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

/// `UseCaseModuleFactoryProtocol`은 Use Case 계층의 모듈을 생성 및 등록하기 위한 기본 인터페이스를 정의합니다.
/// 이 프로토콜을 채택하는 타입은 다음을 제공해야 합니다:
/// 1. `registerModule`: Use Case 모듈 생성 시 필요한 의존성을 등록하는 헬퍼 객체 (`RegisterModule`).
/// 2. `useCaseDefinitions`: 각 `Module` 인스턴스를 생성하는 클로저들의 배열.
/// 3. `makeAllModules()`: `useCaseDefinitions` 배열의 모든 클로저를 실행하여 생성된 `Module` 인스턴스들의 배열을 반환하는 기능.
///
/// ## 역할
/// - `registerModule`을 활용해, Use Case 모듈 구현체가 의존하는 Repository 등을 DI 컨테이너에 등록할 수 있습니다.
/// - `useCaseDefinitions`에 `Module` 생성 클로저를 정의하여, DI 컨테이너에 등록할 Use Case 모듈을 선언적으로 나열합니다.
/// - `makeAllModules()`를 호출하면 모든 정의된 `Module` 인스턴스를 일괄 생성합니다.
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
///     /// - `AuthUseCaseProtocol` 타입의 `DefaultAuthUseCase` 인스턴스를 생성하고,
///     ///   `AuthRepositoryProtocol`을 자동으로 주입받습니다.
///     public var useCaseDefinitions: [() -> Module] {
///         let helper = registerModule  // self를 직접 캡처하지 않도록 복사
///         return [
///             helper.makeUseCaseWithRepository(
///                 AuthUseCaseProtocol.self,              // 등록할 Use Case 프로토콜
///                 repositoryProtocol: AuthRepositoryProtocol.self,  // 주입받을 Repository 프로토콜
///                 repositoryFallback: DefaultAuthRepository()       // Repository가 없을 때 사용할 기본 인스턴스
///             ) { repo in
///                 DefaultAuthUseCase(repository: repo) // 주입된 Repository로 생성한 Use Case
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
///         // 값 타입 복사를 통해 캡처 문제 방지
///         let factoryCopy = self.useCaseFactory
///
///         await registerDependencies { container in
///             // 정의된 모든 Module 인스턴스를 순회하며 Container에 등록
///             for module in factoryCopy.makeAllModules() {
///                 await container.register(module)
///             }
///         }
///     }
/// }
/// ```
///
/// 4) 앱 초기화 시점 예시 (SwiftUI `@main` 또는 UIKit `AppDelegate`)
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
public protocol UseCaseModuleFactoryProtocol {
    // MARK: - 프로퍼티

    /// Use Case 모듈 생성 시 필요한 의존성을 등록하기 위한 헬퍼 객체 (`RegisterModule`).
    var registerModule: RegisterModule { get }

    /// Use Case 모듈을 생성하는 클로저들의 배열.
    /// 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
    var useCaseDefinitions: [() -> Module] { get }

    // MARK: - 메서드

    /// `useCaseDefinitions` 배열의 모든 클로저를 실행하여, 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    func makeAllModules() -> [Module]
}



/// `UseCaseModuleFactoryProtocol`은 Use Case 계층의 모듈을 생성 및 등록하기 위한 기본 인터페이스를 정의합니다.
/// 이 프로토콜을 채택하는 타입은 다음을 제공해야 합니다:
/// 1. `registerModule`: Use Case 모듈 생성 시 필요한 의존성을 등록하는 헬퍼 객체 (`RegisterModule`).
/// 2. `useCaseDefinitions`: 각 `Module` 인스턴스를 생성하는 클로저들의 배열.
/// 3. `makeAllModules()`: `useCaseDefinitions` 배열의 모든 클로저를 실행하여 생성된 `Module` 인스턴스들의 배열을 반환하는 기능.
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


// MARK: - 기본 구현 제공
public extension UseCaseModuleFactoryProtocol {
    /// `useCaseDefinitions` 배열의 모든 클로저를 호출하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    func makeAllModules() -> [Module] {
        useCaseDefinitions.map { $0() }
    }
}
