//
//  Module.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation

/// `Module`는 DI(의존성 주입)를 위한 단일 모듈을 나타내는 구조체입니다.
/// 이 타입을 사용하면, 특정 타입의 인스턴스를 `DependencyContainer`에 등록하는
/// 비동기 작업을 캡슐화할 수 있습니다.
///
/// ## Declaration
///
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
/// ### Parameters
/// - `type`: 등록할 의존성의 타입. 예를 들어 `AuthRepositoryProtocol.self`,
///   `UserServiceProtocol.self` 등.
/// - `factory`: 해당 타입 `T`의 인스턴스를 생성하는 팩토리 클로저.
///   이 클로저는 `@Sendable` 어노테이션을 사용하여 비동기 안전성을 보장해야 합니다.
///
/// ## Topics
///
/// ### Stored Properties
///
/// ```swift
/// private let registrationClosure: @Sendable () async -> Void
/// ```
///
/// - **`registrationClosure`**
///   - 내부적으로 보관되는 비동기 클로저입니다.
///   - 생성 시점에 전달된 `type` 및 `factory`를 사용해,
///     `DependencyContainer.live.register(type, build: factory)`를 호출하도록 구성됩니다.
///   - 즉, 이 클로저을 실행하면 DI 컨테이너에 해당 타입의 인스턴스를 등록하는 작업이 수행됩니다.
///   - `Module` 인스턴스가 만들어지면, 실제 의존성 등록 로직은 무조건
///     이 `registrationClosure` 내부에서만 실행되며, 외부에서는 직접 접근할 수 없습니다.
///   - `register()` 메서드가 호출될 때 비동기적으로 이 클로저가 실행됩니다.
///
/// ### Initializers
///
/// ```swift
/// public init<T>(
///     _ type: T.Type,
///     factory: @escaping @Sendable () -> T
/// )
/// ```
///
/// - **설명**
///   - 주어진 타입 `T`와 팩토리 클로저를 사용하여 내부 비동기 클로저
///     (`registrationClosure`)를 구성합니다.
///   - 이 클로저는 호출되면 `DependencyContainer.live.register(type, build: factory)`를 실행하여
///     DI 컨테이너에 실제 의존성을 등록합니다.
///
/// - **Parameters**
///   - `type`: 등록할 의존성의 타입.
///   - `factory`: 해당 타입 `T`의 인스턴스를 생성하는 **`@Sendable`** 팩토리 클로저.
///
/// ### Instance Methods
///
/// ```swift
/// public func register() async
/// ```
///
/// - **설명**
///   - 저장된 `registrationClosure`를 실행하여, 비동기적으로 DI 컨테이너에 의존성을 등록합니다.
///   - 반드시 `await` 키워드를 사용하여 호출해야 하며, 등록 작업이 완료될 때까지 대기합니다.
///   - 내부적으로는 생성 시점에 캡슐화된 `(type, factory)` 정보를 사용하여 컨테이너에 등록하는 로직만 수행합니다.
///
/// - **Example**
///
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
///       // 이후:
///       // let service: NetworkServiceProtocol =
///       //     DependencyContainer.live.resolve(NetworkServiceProtocol.self)!
///       // service.request(...)
///   }
///   ```
///
/// - **Concurrency**
///   - 이 메서드는 `async`로 선언되어, 호출하는 시점에 반드시 `await`로 대기해야 합니다.
///   - 내부적으로는 `registrationClosure` 자체가 비동기 클로저이므로,
///     호출 간에 다른 작업이 스케줄링될 수 있습니다.
///
/// ### Relationships
///
/// - Conforms To: `Swift.Sendable`
///
/// ## Example (전체 흐름)
///
/// 아래 예시에서는 `UserServiceProtocol` 타입의 구현체를 `Module`로 만들어
/// DI 컨테이너에 등록하는 전체 과정을 보여줍니다.
///
/// ```swift
/// import DiContainer
/// import Foundation
///
/// // 1) 프로토콜 및 기본 구현체 정의
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
/// // 2) AppDIContainer에 Module 등록 메서드 추가
/// extension AppDIContainer {
///     /// `UserServiceProtocol` 타입을 DI 컨테이너에 등록하는 Module 생성 예시
///     public func registerUserServiceModule() async {
///         // Module 초기화: UserServiceProtocol ↔ DefaultUserService 연결
///         let userServiceModule = Module(
///             UserServiceProtocol.self,
///             factory: { DefaultUserService() }
///         )
///
///         // Module을 DI 컨테이너에 등록
///         // `register()` 호출 시 반드시 `await` 사용
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
///
/// ### Note
/// - `Module` 생성 시 전달하는 `factory` 클로저는 반드시 `@Sendable`로 선언해야 합니다.
/// - `register()` 호출 시 반드시 `await` 키워드를 사용해야 하며,
///   등록이 완료될 때까지 대기합니다.
/// - 등록된 의존성은 이후에 `DependencyContainer.live.resolve(...)` 형태로 꺼내 사용할 수 있습니다.
public struct Module: Sendable {
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
    private let registrationClosure: @Sendable () async -> Void

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
        factory: @escaping @Sendable () -> T
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
/// `Module`는 DI(의존성 주입)를 위한 단일 모듈을 나타내는 구조체입니다.
/// 이 타입을 사용하면, 특정 타입의 인스턴스를 `DependencyContainer`에 등록하는
/// 비동기 작업을 캡슐화할 수 있습니다.
///
/// ## Declaration
///
/// ```swift
/// public struct Module {
///     public init<T>(
///         _ type: T.Type,
///         factory: @escaping () -> T
///     )
///
///     public func register() async
/// }
/// ```
///
/// ## Topics
///
/// ### Stored Properties
///
/// ```swift
/// private let registrationClosure: () async -> Void
/// ```
///
/// - **`registrationClosure`**
///   - 내부에 보관되는 비동기 클로저입니다.
///   - 생성 시점에 전달된 `type` 및 `factory`를 사용해,
///     `DependencyContainer.live.register(type, build: factory)`를 호출하도록 구성됩니다.
///   - 호출할 때 실제 의존성 등록 로직을 실행하며, 외부에서는 직접 접근하지 않습니다.
///
/// ### Initializers
///
/// ```swift
/// public init<T>(
///     _ type: T.Type,
///     factory: @escaping () -> T
/// )
/// ```
///
/// - **설명**
///   - 주어진 타입 `T`와 팩토리 클로저를 사용하여 내부 비동기 클로저
///     (`registrationClosure`)를 구성합니다.
///   - 이 클로저는 나중에 `register()`가 호출될 때 실행되어,
///     `DependencyContainer.live.register(type, build: factory)`를 수행합니다.
///
/// - **Parameters**
///   - `type`: 등록할 의존성의 타입. 예: `AuthRepositoryProtocol.self`
///   - `factory`: 해당 타입 `T`의 인스턴스를 생성하는 팩토리 클로저.
///
/// ### Instance Methods
///
/// ```swift
/// public func register() async
/// ```
///
/// - **설명**
///   - 저장된 `registrationClosure`를 실행하여, 비동기적으로 해당 의존성을
///     DI 컨테이너에 등록합니다. 반드시 `await` 키워드를 사용하여 호출해야 하며,
///     등록 작업이 완료될 때까지 대기합니다.
///
/// - **Example**
///
///   ```swift
///   let analyticsModule = Module(
///       AnalyticsServiceProtocol.self,
///       factory: { FirebaseAnalyticsService() }
///   )
///   Task {
///       await analyticsModule.register()
///       let analytics: AnalyticsServiceProtocol =
///           DependencyContainer.live.resolve(AnalyticsServiceProtocol.self)!
///       analytics.track(event: "app_start")
///   }
///   ```
///
/// - **Notes**
///   - `Module` 생성 시 `factory` 클로저를 꼭 제공해야 하며,
///     `register()` 호출 시 반드시 `await` 사용이 필요합니다.
///   - DI 컨테이너에 등록된 후, `DependencyContainer.live.resolve(...)`로 인스턴스를 꺼낼 수 있습니다.
///
//@available(iOS, introduced: 13.0, obsoleted: 17.0)
//public struct Module {
//    // MARK: – Stored Properties
//
//    /// `registrationClosure`는 비동기 클로저로, 해당 모듈의 의존성을
//    /// `DependencyContainer`에 등록하는 작업을 수행합니다.
//    private let registrationClosure: () async -> Void
//
//    // MARK: – Initialization
//
//    /// Module 생성자
//    ///
//    /// - Parameters:
//    ///   - `type`: 등록할 의존성의 타입 (예: `AuthRepositoryProtocol.self`).
//    ///   - `factory`: 해당 타입 `T`의 인스턴스를 생성하는 팩토리 클로저.
//    ///
//    /// 이 생성자는 `DependencyContainer.live.register(type, build: factory)`를 래핑하는
//    /// 비동기 클로저를 `registrationClosure`에 저장합니다.
//    public init<T>(
//        _ type: T.Type,
//        factory: @escaping () -> T
//    ) {
//        self.registrationClosure = {
//            DependencyContainer.live.register(type, build: factory)
//        }
//    }
//
//    // MARK: – Instance Method
//
//    /// `registrationClosure`를 실행하여, 비동기적으로 의존성을
//    /// 컨테이너에 등록합니다. 반드시 `await` 사용이 필요합니다.
//    public func register() async {
//        await registrationClosure()
//    }
//}

