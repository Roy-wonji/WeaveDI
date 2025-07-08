//
//  RepositoryModuleFactoryProtocol.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation


/// `RepositoryModuleFactoryProtocol`은 Repository 모듈을 생성하고 등록하기 위한 기본 인터페이스를 정의합니다.
///
/// - `registerModule`: 의존성 등록 헬퍼 객체(`RegisterModule`)로, 각 Repository 모듈을 구성할 때 필요한 의존성을 등록합니다.
/// - `repositoryDefinitions`: Repository 모듈 생성 클로저들의 배열. 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
/// - `makeAllModules()`: 내부 `repositoryDefinitions` 배열의 모든 클로저를 실행하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
///
/// ## 역할
/// 1. `registerModule` 프로퍼티를 통해, Repository 모듈을 만들 때 필요한 다른 의존성을 DI 컨테이너에 등록할 수 있습니다.
/// 2. `repositoryDefinitions` 배열에 `Module` 생성 클로저를 추가함으로써, DI 컨테이너에 등록할 모듈을 정의합니다.
/// 3. `makeAllModules()` 호출 시 모든 정의(closed)를 실행하여, `Module` 인스턴스를 일괄 생성합니다.
///
/// ## 사용 예시
///
/// 1) 프로토콜 정의 및 기본 구현체 작성
/// ```swift
/// import Foundation
///
/// protocol AuthRepositoryProtocol {
///     func login(user: String, password: String) async -> Bool
/// }
///
/// struct DefaultAuthRepository: AuthRepositoryProtocol {
///     func login(user: String, password: String) async -> Bool {
///         // 실제 로그인 로직 구현
///         return true
///     }
/// }
/// ```
///
/// 2) `RepositoryModuleFactoryProtocol`을 채택하는 팩토리 타입 생성
/// ```swift
/// import DiContainer
///
/// struct AuthRepositoryModuleFactory: RepositoryModuleFactoryProtocol {
///     // 의존성 등록 헬퍼 인스턴스
///     let registerModule = RegisterModule()
///
///     // AuthRepositoryProtocol을 생성하는 Module 클로저를 배열에 정의
///     var repositoryDefinitions: [() -> Module] {
///         [
///             // `makeDependency` 사용 예시: `AuthRepositoryProtocol`에 `DefaultAuthRepository`를 매핑
///             registerModule.makeDependency(AuthRepositoryProtocol.self) {
///                 DefaultAuthRepository()
///             }
///         ]
///     }
/// }
/// ```
///
/// 3) `AppDIContainer` 내에서 호출하여 DI 컨테이너에 모듈 등록
/// ```swift
/// import DiContainer
///
/// extension AppDIContainer {
///     public func registerAuthRepository() async {
///         // 팩토리 복사(값 타입인 경우 캡처 문제 방지)
///         var factoryCopy = AuthRepositoryModuleFactory()
///
///         // 등록 클로저 실행: 모듈을 Container에 등록
///         await registerDependencies { container in
///             for module in factoryCopy.makeAllModules() {
///                 await container.register(module)
///             }
///         }
///     }
/// }
/// ```
///
/// 4) 앱 초기화 시점 (SwiftUI `@main` 또는 `AppDelegate`)에서 모듈 등록
/// ```swift
/// import SwiftUI
///
/// @main
/// struct MyApp: App {
///     @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
///
///     init() {
///         // 비동기로 Repository 모듈 등록
///         Task {
///             await AppDIContainer.shared.registerAuthRepository()
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
public protocol RepositoryModuleFactoryProtocol {
    // MARK: - 프로퍼티

    /// Repository 모듈 생성 시 사용되는 의존성 등록 헬퍼 객체.
    var registerModule: RegisterModule { get }

    /// Repository 모듈을 생성하는 클로저들의 배열.
    /// 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
    var repositoryDefinitions: [() -> Module] { get }

    // MARK: - 메서드

    /// `repositoryDefinitions` 배열에 있는 모든 클로저를 실행하여, 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    func makeAllModules() -> [Module]
}


/// `RepositoryModuleFactoryProtocol`은 Repository 모듈을 생성하고 등록하기 위한 기본 인터페이스를 정의합니다.
/// - `registerModule`: 의존성 등록 헬퍼 객체(`RegisterModule`)로, 각 Repository 모듈을 구성할 때 필요한 의존성을 등록합니다.
/// - `repositoryDefinitions`: Repository 모듈 생성 클로저들의 배열. 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
/// - `makeAllModules()`: 내부 `repositoryDefinitions` 배열의 모든 클로저를 실행하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
///
/// ## 사용 예시
///
/// 1) 프로토콜 정의 및 기본 구현체 작성
/// ```swift
/// import Foundation
///
/// protocol AuthRepositoryProtocol {
///     func login(user: String, password: String) -> Bool
/// }
///
/// struct DefaultAuthRepository: AuthRepositoryProtocol {
///     func login(user: String, password: String) -> Bool {
///         // 실제 로그인 로직 구현
///         return true
///     }
/// }
/// ```
///
/// 2) `RepositoryModuleFactoryProtocol`을 채택하는 팩토리 타입 생성
/// ```swift
/// import DiContainer
///
/// struct AuthRepositoryModuleFactory: RepositoryModuleFactoryProtocol {
///     // 의존성 등록 헬퍼 인스턴스
///     let registerModule = RegisterModule()
///
///     // AuthRepositoryProtocol을 생성하는 Module 클로저를 배열에 정의
///     var repositoryDefinitions: [() -> Module] {
///         [
///             // `makeDependency` 사용 예시: `AuthRepositoryProtocol`에 `DefaultAuthRepository`를 매핑
///             registerModule.makeDependency(AuthRepositoryProtocol.self) {
///                 DefaultAuthRepository()
///             }
///         ]
///     }
/// }
/// ```
///
/// 3) `AppDIContainer` 내에서 호출하여 DI 컨테이너에 모듈 등록
/// ```swift
/// import DiContainer
///
/// extension AppDIContainer {
///     public func registerAuthRepository() async {
///         // 팩토리 복사(값 타입인 경우 캡처 문제 방지)
///         var factoryCopy = AuthRepositoryModuleFactory()
///
///         // 등록 클로저 실행: 모듈을 Container에 등록
///         await registerDependencies { container in
///             for module in factoryCopy.makeAllModules() {
///                 await container.register(module)
///             }
///         }
///     }
/// }
/// ```
///
/// 4) 앱 초기화 시점 (UIKit `AppDelegate`)에서 모듈 등록
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
///             await AppDIContainer.shared.registerAuthRepository()
///         }
///         return true
///     }
/// }
/// ```
// MARK: - 기본 구현 제공
public extension RepositoryModuleFactoryProtocol {
    /// `repositoryDefinitions` 배열의 모든 클로저를 호출하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    func makeAllModules() -> [Module] {
        repositoryDefinitions.map { $0() }
    }
}
