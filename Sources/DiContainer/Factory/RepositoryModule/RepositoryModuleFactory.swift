//
//  RepositoryModuleFactory.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//


import Foundation

#if swift(>=5.9)
@available(iOS 17.0, *)
/// `RepositoryModuleFactory`는 `RepositoryModuleFactoryProtocol`을 채택하여
/// Repository 계층의 모듈 생성 및 등록을 담당하는 타입입니다.
///
/// - `registerModule`: 의존성 등록 헬퍼(`RegisterModule`) 인스턴스입니다.
///   이 헬퍼를 통해 Repository 모듈을 생성하는 클로저를 등록하고,
///   `Module` 인스턴스를 구성합니다.
/// - `repositoryDefinitions`: Repository 모듈을 생성하는 클로저들의 배열입니다.
///   각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
/// - `makeAllModules()`: 내부 `repositoryDefinitions` 배열에 있는 모든 클로저를 실행하여,
///   생성된 `Module` 인스턴스들의 배열을 반환합니다.
///
/// ## 사용 예시
///
/// 1) 기본 Repository 정의 확장
/// ```swift
/// import DiContainer
///
/// protocol AuthRepositoryProtocol {
///     func login(user: String, password: String) async -> Bool
/// }
///
/// struct DefaultAuthRepository: AuthRepositoryProtocol {
///     func login(user: String, password: String) async -> Bool {
///         // 실제 로그인 로직
///         return true
///     }
/// }
///
/// extension RepositoryModuleFactory {
///     /// 기본 Repository 의존성 정의를 설정합니다.
///     /// - `registerModule.makeDependency(AuthRepositoryProtocol.self) { DefaultAuthRepository() }`
///     ///   클로저는 `AuthRepositoryProtocol` 타입의 `DefaultAuthRepository`를 반환합니다.
///     public mutating func registerDefaultDefinitions() {
///         let helper = registerModule  // self를 직접 캡처하지 않도록 복사
///         repositoryDefinitions = [
///             helper.makeDependency(AuthRepositoryProtocol.self) { DefaultAuthRepository() }
///         ]
///     }
/// }
/// ```
///
/// 2) AppDIContainer에서 호출하여 DI 컨테이너에 등록
/// ```swift
/// import DiContainer
///
/// extension AppDIContainer {
///     public func registerDefaultRepositoryModules() async {
///         var factoryCopy = repositoryFactory
///         await registerDependencies { container in
///             // DefaultAuthRepository 등록
///             factoryCopy.registerDefaultDefinitions()
///
///             // 생성된 Module 배열을 순회하며 Container에 등록
///             for module in factoryCopy.makeAllModules() {
///                 await container.register(module)
///             }
///         }
///     }
/// }
/// ```
///
/// 3) 실제 앱 초기화 시점 예시
/// ```swift
/// import SwiftUI
///
/// @main
/// struct MyApp: App {
///     @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
///
///     init() {
///         Task {
///             await AppDIContainer.shared.registerDefaultRepositoryModules()
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
public struct RepositoryModuleFactory: RepositoryModuleFactoryProtocol {
    // MARK: - 저장 프로퍼티

    /// 의존성 등록 헬퍼 객체(`RegisterModule`)입니다.
    /// - Repository 모듈 생성 시 필요한 의존성 등록 로직을 이 헬퍼를 통해 수행합니다.
    public let registerModule = RegisterModule()

    /// Repository 모듈을 생성하는 클로저들의 배열입니다.
    /// - 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
    public var repositoryDefinitions: [() -> Module]

    // MARK: - 초기화

    /// 생성자
    ///
    /// - Parameter repositoryDefinitions: 모듈 생성 클로저 배열을 전달할 수 있습니다.
    ///   - 만약 `nil`이 전달되면, 기본 의존성 정의는 빈 배열로 초기화됩니다.
    ///   - 애플리케이션에서는 `extension`을 통해 이 배열을 재정의하여 사용합니다.
    public init(repositoryDefinitions: [() -> Module]? = nil) {
        self.repositoryDefinitions = repositoryDefinitions ?? []
    }

    // MARK: - 메서드

    /// `repositoryDefinitions` 배열의 모든 클로저를 실행하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    public func makeAllModules() -> [Module] {
        repositoryDefinitions.map { $0() }
    }
}

#else

/// `RepositoryModuleFactory`는 `RepositoryModuleFactoryProtocol`을 채택하여
/// Repository 계층의 모듈 생성 및 등록을 담당하는 타입입니다.
///
/// - `registerModule`: 의존성 등록 헬퍼(`RegisterModule`) 인스턴스입니다.
/// - `repositoryDefinitions`: Repository 모듈을 생성하는 클로저들의 배열입니다.
/// - `makeAllModules()`: 내부 `repositoryDefinitions` 배열에 있는 모든 클로저를 실행하여,
///   생성된 `Module` 인스턴스들의 배열을 반환합니다.
///
/// ## 사용 예시 (Swift 5.9 미만 / iOS 17.0 미지원)
///
/// 1) 기본 Repository 정의 확장
/// ```swift
/// import DiContainer
///
/// protocol AuthRepositoryProtocol {
///     func login(user: String, password: String) -> Bool
/// }
///
/// struct DefaultAuthRepository: AuthRepositoryProtocol {
///     func login(user: String, password: String) -> Bool {
///         // 실제 로그인 로직
///         return true
///     }
/// }
///
/// extension RepositoryModuleFactory {
///     /// 기본 Repository 의존성 정의를 설정합니다.
///     public mutating func registerDefaultDefinitions() {
///         let helper = registerModule  // self를 직접 캡처하지 않기 위해 복사
///         repositoryDefinitions = [
///             helper.makeDependency(AuthRepositoryProtocol.self) { DefaultAuthRepository() }
///         ]
///     }
/// }
/// ```
///
/// 2) AppDIContainer에서 호출하여 DI 컨테이너에 등록
/// ```swift
/// import DiContainer
///
/// extension AppDIContainer {
///     public func registerDefaultRepositoryModules() async {
///         var factoryCopy = repositoryFactory
///         await registerDependencies { container in
///             factoryCopy.registerDefaultDefinitions()
///             for module in factoryCopy.makeAllModules() {
///                 await container.register(module)
///             }
///         }
///     }
/// }
/// ```
///
/// 3) 실제 앱 초기화 시점 예시
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
///             await AppDIContainer.shared.registerDefaultRepositoryModules()
///         }
///         return true
///     }
/// }
/// ```
public struct RepositoryModuleFactory: RepositoryModuleFactoryProtocol {
    // MARK: - 저장 프로퍼티

    /// 의존성 등록 헬퍼 객체(`RegisterModule`)입니다.
    public let registerModule = RegisterModule()

    /// Repository 모듈을 생성하는 클로저들의 배열입니다.
    public var repositoryDefinitions: [() -> Module]

    // MARK: - 초기화

    /// 생성자
    ///
    /// - Parameter repositoryDefinitions: 모듈 생성 클로저 배열을 전달할 수 있습니다.
    ///   - `nil`이 전달되면 기본 의존성 정의는 빈 배열로 초기화됩니다.
    public init(repositoryDefinitions: [() -> Module]? = nil) {
        self.repositoryDefinitions = repositoryDefinitions ?? []
    }

    // MARK: - 메서드

    /// `repositoryDefinitions` 배열의 모든 클로저를 실행하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    public func makeAllModules() -> [Module] {
        repositoryDefinitions.map { $0() }
    }
}
#endif
