//
//  Module.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation

/// `Module`은 DI(의존성 주입)를 위한 **단일 모듈**을 나타내는 구조체입니다.
///
/// 이 타입을 사용하면, 특정 타입의 인스턴스를 `DependencyContainer`에
/// **비동기적으로 등록**하는 작업을 하나의 객체로 캡슐화할 수 있습니다.
///
/// ## Declaration
/// ```swift
/// public struct Module: Sendable {
///     public init<T>(
///         _ type: T.Type,
///         factory: @escaping @Sendable () -> T
///     )
///
///     public func register() async
/// }
/// ```
///
/// - Note: `factory` 파라미터는 반드시 `@Sendable`로 선언하여 스레드 안정성을 보장해야 합니다.
///
/// ## Stored Properties
/// - `registrationClosure`:
///   내부에 저장된 비동기 클로저로, `register()` 호출 시 실행됩니다.
///   생성 시 전달받은 `(type, factory)` 정보를 기반으로
///   `DependencyContainer.live.register(type, build: factory)`를 호출하도록 구성됩니다.
///
/// ## Initializers
///
/// ### `init(_:factory:)`
/// 주어진 타입과 팩토리 클로저를 사용해 `Module` 인스턴스를 초기화합니다.
///
/// ```swift
/// public init<T>(
///     _ type: T.Type,
///     factory: @escaping @Sendable () -> T
/// )
/// ```
///
/// - Parameters:
///   - type: 등록할 의존성 타입 (예: `AuthRepositoryProtocol.self`)
///   - factory: 해당 타입의 인스턴스를 생성하는 클로저. `@Sendable` 필수.
///
/// - Important: 생성된 `Module`은 `register()`를 호출해야만 DI 컨테이너에 등록됩니다.
///
/// ## Instance Methods
///
/// ### `register()`
///
/// 저장된 `registrationClosure`를 실행하여 DI 컨테이너에 의존성을 등록합니다.
///
/// ```swift
/// public func register() async
/// ```
///
/// - Important: 반드시 `await` 키워드와 함께 호출해야 하며,
///   등록이 완료될 때까지 비동기적으로 대기합니다.
/// - Concurrency: 비동기 메서드이므로 호출 간 다른 작업이 스케줄링될 수 있습니다.
///
/// #### Example
/// ```swift
/// // 1) Module 생성
/// let networkModule = Module(
///     NetworkServiceProtocol.self,
///     factory: { DefaultNetworkService() }
/// )
///
/// // 2) Module 등록
/// Task {
///     await networkModule.register()
///     // 이후 의존성 사용
///     let service: NetworkServiceProtocol =
///         DependencyContainer.live.resolve(NetworkServiceProtocol.self)!
///     await service.request(...)
/// }
/// ```
///
/// ## Example – 전체 흐름
///
/// 아래는 `UserServiceProtocol` 타입을 DI 컨테이너에 등록하는 예시입니다.
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
///         return User(id: id, name: "Test User")
///     }
/// }
///
/// extension AppDIContainer {
///     public func registerUserServiceModule() async {
///         let userServiceModule = Module(
///             UserServiceProtocol.self,
///             factory: { DefaultUserService() }
///         )
///
///         await registerDependencies { container in
///             await container.register(userServiceModule)
///         }
///     }
/// }
///
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
///
/// ## Relationships
/// - Conforms to: `Sendable`
///
/// ## See Also
/// - ``DependencyContainer``
///
public actor Module {
  /// ### Instance Methods
  // MARK: – Stored Properties
  /// 비동기 클로저로, `DependencyContainer`에 의존성을 등록하는 작업을 수행합니다.
  /// - 생성 시점:
  ///   `init(_ type: T.Type, factory: @Sendable () -> T)` 호출 시 내부에서 구성됨.
  /// - 기능:
  ///   호출되면 `DependencyContainer.live.register(type, build: factory)`를 실행하여
  ///   DI 컨테이너에 `type` ↔ `factory()` 매핑을 등록합니다.
  /// - 접근 제한:
  ///   외부에서는 직접 접근할 수 없고, 오직 `register()` 메서드를 통해서만 실행됩니다.

  private let registrationClosure:  () async -> Void

  // MARK: – Initialization

  /// Module 생성자
  ///
  /// - Parameters:
  ///   - `type`: 등록할 의존성의 타입 (예: `AuthRepositoryProtocol.self`).
  ///   - `factory`: 해당 타입 `T`의 인스턴스를 생성하는 **`@Sendable`** 팩토리 클로저.
  ///
  /// 이 생성자는 내부 비동기 클로저(`registrationClosure`)를 구성하여
  /// `DependencyContainer.live.register(type, build: factory)`를 호출하도록 캡슐화합니다.
  /// 이때 생성된 클로저는 외부에 노출되지 않으며, `register()` 메서드를 통해 실행됩니다.
  public init<T>(
    _ type: T.Type,
    factory: @escaping () -> T
  ) {
    // registrationClosure 내부에서는 반드시 `DependencyContainer.live`를 사용하여
    // 비동기로 의존성을 등록하도록 구현합니다.
    self.registrationClosure = {
      DependencyContainer.live.register(type, build: factory)
    }
  }

  // MARK: – Instance Method

  /// 저장된 `registrationClosure`를 실행하여, 비동기적으로 의존성을 DI 컨테이너에 등록합니다.
  ///
  /// - Discussion:
  ///   1. 이 메서드는 `async`로 선언되어 있으며, 호출 시 반드시 `await` 키워드를 사용해야 합니다.
  ///   2. 내부적으로 `registrationClosure`를 실행하면서,
  ///      `DependencyContainer.live.register(type, build: factory)` 호출이 이루어집니다.
  ///   3. 호출 후 리턴 시점까지는 등록 작업이 완료될 때까지 대기 상태가 유지됩니다.
  ///   4. 예를 들어, `await module.register()`를 호출하면,
  ///      해당 `Module` 인스턴스에 캡슐화된 `type`과 `factory` 정보를 바탕으로
  ///      DI 컨테이너에 의존성이 등록됩니다.
  ///
  /// - Example:
  ///   ```swift
  ///   // 1) Module 생성
  ///   let networkModule = Module(
  ///       NetworkServiceProtocol.self,
  ///       factory: { DefaultNetworkService() }
  ///   )
  ///
  ///   // 2) Module을 DI 컨테이너에 등록 (비동기 대기)
  ///   Task {
  ///       await networkModule.register()
  ///
  ///       // 3) DI 컨테이너에서 인스턴스 꺼내기
  ///       let service: NetworkServiceProtocol =
  ///           DependencyContainer.live.resolve(NetworkServiceProtocol.self)!
  ///       service.request(...)
  ///   }
  ///   ```
  ///
  /// - Concurrency:
  ///   - 이 메서드는 `async`로 선언되어 있어, 호출 시점에서 반드시 `await`로 대기해야 합니다.
  ///   - 내부적으로는 `registrationClosure` 자체가 비동기 클로저이므로,
  ///     호출 간에 다른 작업이 스케줄링될 수 있습니다.
  ///
  /// - Parameters:
  ///   - 없음
  /// - Returns:
  ///   - `Void` (등록 작업이 완료되면 메서드가 리턴됨)
  public func register() async {
    await registrationClosure()
  }
}
