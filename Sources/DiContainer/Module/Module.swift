//
//  Module.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation

#if swift(>=5.9)
@available(iOS 17.0, *)
/// `Module`는 DI(의존성 주입)를 위한 단일 모듈을 나타내는 구조체입니다.
/// 이 타입을 사용하면, 특정 타입의 인스턴스를 `DependencyContainer`에 등록하는 비동기 작업을 캡슐화할 수 있습니다.
///
/// - `registrationClosure`: 주어진 타입과 팩토리 클로저를 이용해 비동기적으로 `DependencyContainer.live`에 의존성을 등록합니다.
/// - `register()`: 내부에 저장된 `registrationClosure`를 실행하여, 비동기적으로 의존성을 컨테이너에 등록합니다.
///
/// ## 사용 예시
///
/// 1) Module 프로토콜/타입이 필요한 상황 – 예를 들어, UserServiceProtocol을 DI 컨테이너에 등록하고 싶을 때:
///
/// ```swift
/// import DiContainer
///
/// protocol UserServiceProtocol {
///     func fetchUser(id: String) async -> User?
/// }
///
/// struct DefaultUserService: UserServiceProtocol {
///     func fetchUser(id: String) async -> User? {
///         // 네트워크 요청 등을 수행하여 사용자 정보를 반환
///         return User(id: id, name: "Test User")
///     }
/// }
///
/// // 2) AppDIContainer에 모듈 등록
/// extension AppDIContainer {
///     /// UserServiceProtocol을 DI 컨테이너에 등록하는 Module 생성 예시
///     public func registerUserServiceModule() async {
///         // Module 초기화: UserServiceProtocol ↔ DefaultUserService 연결
///         let userServiceModule = Module(
///             UserServiceProtocol.self,
///             factory: { DefaultUserService() }
///         )
///
///         // Module을 DI 컨테이너에 등록
///         await registerDependencies { container in
///             await container.register(userServiceModule)
///         }
///     }
/// }
///
/// // 3) 앱 초기화 시점 (SwiftUI @main)
/// import SwiftUI
///
/// @main
/// struct MyApp: App {
///     init() {
///         Task {
///             await AppDIContainer.shared.registerUserServiceModule()
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
public struct Module: Sendable {
    // MARK: - 저장 프로퍼티

    /// `registrationClosure`는 비동기 클로저로, 해당 모듈의 의존성을 `DependencyContainer`에 등록하는 작업을 수행합니다.
    private let registrationClosure: @Sendable () async -> Void

    // MARK: - 초기화

    /// 생성자
    ///
    /// - Parameters:
    ///   - type: 등록할 의존성의 타입 (예: `AuthRepositoryProtocol.self`)
    ///   - factory: 해당 타입의 인스턴스를 생성하는 비동기 안전 팩토리 클로저
    ///
    /// 전달받은 `type`과 `factory` 클로저를 사용하여,
    /// `DependencyContainer.live`에 의존성을 등록하는 비동기 클로저를 생성해 `registrationClosure`에 저장합니다.
    public init<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) {
        self.registrationClosure = {
            DependencyContainer.live.register(type, build: factory)
        }
    }

    // MARK: - 메서드

    /// `register()` 메서드는 `registrationClosure`를 실행하여, 비동기적으로 의존성을 등록합니다.
    /// 호출 시 `await`를 사용하여 완료될 때까지 대기합니다.
    public func register() async {
        await registrationClosure()
    }
}

#else
/// `Module`는 DI(의존성 주입)를 위한 단일 모듈을 나타내는 구조체입니다.
/// 이 타입을 사용하면, 특정 타입의 인스턴스를 `DependencyContainer`에 등록하는 비동기 작업을 캡슐화할 수 있습니다.
///
/// - `registrationClosure`: 주어진 타입과 팩토리 클로저를 이용해 비동기적으로 `DependencyContainer.live`에 의존성을 등록합니다.
/// - `register()`: 내부에 저장된 `registrationClosure`를 실행하여, 비동기적으로 의존성을 컨테이너에 등록합니다.
///
/// ## 사용 예시
///
/// 1) Module 프로토콜/타입이 필요한 상황 – 예를 들어, UserServiceProtocol을 DI 컨테이너에 등록하고 싶을 때:
///
/// ```swift
/// import DiContainer
///
/// protocol UserServiceProtocol {
///     func fetchUser(id: String) -> User?
/// }
///
/// struct DefaultUserService: UserServiceProtocol {
///     func fetchUser(id: String) -> User? {
///         // 로컬 또는 네트워크에서 사용자 정보를 반환
///         return User(id: id, name: "Test User")
///     }
/// }
///
/// // 2) AppDIContainer에 모듈 등록
/// extension AppDIContainer {
///     /// UserServiceProtocol을 DI 컨테이너에 등록하는 Module 생성 예시
///     public func registerUserServiceModule() async {
///         // Module 초기화: UserServiceProtocol ↔ DefaultUserService 연결
///         let userServiceModule = Module(
///             UserServiceProtocol.self,
///             factory: { DefaultUserService() }
///         )
///
///         // Module을 DI 컨테이너에 등록
///         await registerDependencies { container in
///             await container.register(userServiceModule)
///         }
///     }
/// }
///
/// // 3) 앱 초기화 시점 (UIKit AppDelegate)
/// import UIKit
///
/// @main
/// class AppDelegate: UIResponder, UIApplicationDelegate {
///     func application(
///         _ application: UIApplication,
///         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
///     ) -> Bool {
///         Task {
///             await AppDIContainer.shared.registerUserServiceModule()
///         }
///         return true
///     }
/// }
/// ```
public struct Module {
    // MARK: - 저장 프로퍼티

    /// `registrationClosure`는 비동기 클로저로, 해당 모듈의 의존성을 `DependencyContainer`에 등록하는 작업을 수행합니다.
    private let registrationClosure: () async -> Void

    // MARK: - 초기화

    /// 생성자
    ///
    /// - Parameters:
    ///   - type: 등록할 의존성의 타입 (예: `AuthRepositoryProtocol.self`)
    ///   - factory: 해당 타입의 인스턴스를 생성하는 팩토리 클로저
    ///
    /// 전달받은 `type`과 `factory` 클로저를 사용하여,
    /// `DependencyContainer.live`에 의존성을 등록하는 비동기 클로저를 생성해 `registrationClosure`에 저장합니다.
    public init<T>(
        _ type: T.Type,
        factory: @escaping () -> T
    ) {
        self.registrationClosure = {
            DependencyContainer.live.register(type, build: factory)
        }
    }

    // MARK: - 메서드

    /// `register()` 메서드는 `registrationClosure`를 실행하여, 비동기적으로 의존성을 등록합니다.
    /// 호출 시 `await`를 사용하여 완료될 때까지 대기합니다.
    public func register() async {
        await registrationClosure()
    }
}
#endif
