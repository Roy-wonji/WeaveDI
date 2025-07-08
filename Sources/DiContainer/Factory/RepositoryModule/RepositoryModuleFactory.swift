//
//  RepositoryModuleFactory.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//


import Foundation

/// `RepositoryModuleFactory`는 `RepositoryModuleFactoryProtocol`을 채택하여
/// Repository 계층의 모듈 생성 및 등록을 담당하는 타입입니다.
///
/// - `registerModule`: 의존성 등록 헬퍼(`RegisterModule`) 인스턴스를 통해
///   Repository 모듈을 구성할 때 필요한 다른 의존성을 DI 컨테이너에 등록할 수 있습니다.
/// - `repositoryDefinitions`: Repository 모듈을 생성하는 클로저들의 배열로,
///   각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
/// - `makeAllModules()`: 내부 `repositoryDefinitions` 배열에 포함된 모든 클로저를 실행하여,
///   생성된 `Module` 인스턴스들의 배열을 반환합니다.
///
/// ## 사용 예시
///
/// 1) 프로토콜 및 기본 구현체 정의
/// ```swift
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
/// 2) `RepositoryModuleFactory` 확장하여 기본 정의 등록
/// ```swift
/// extension RepositoryModuleFactory {
///     /// 기본 Repository 의존성 정의를 설정합니다.
///     public mutating func registerDefaultDefinitions() {
///         let helper = registerModule  // self를 직접 캡처하지 않기 위해 복사
///         repositoryDefinitions = [
///             helper.makeDependency(AuthRepositoryProtocol.self) {
///                 DefaultAuthRepository()
///             }
///         ]
///     }
/// }
/// ```
///
/// 3) `AppDIContainer`에서 호출하여 DI 컨테이너에 모듈 등록
/// ```swift
/// extension AppDIContainer {
///     public func registerAuthRepository() async {
///         // 값 타입인 RepositoryModuleFactory 복사 (클로저 캡처 문제 방지)
///         var factoryCopy = RepositoryModuleFactory()
///
///         // 기본 정의 등록
///         factoryCopy.registerDefaultDefinitions()
///
///         // 생성된 모듈들을 비동기적으로 Container에 등록
///         await registerDependencies { container in
///             for module in factoryCopy.makeAllModules() {
///                 await container.register(module)
///             }
///         }
///     }
/// }
/// ```
///
/// 4) 앱 초기화 시점 (SwiftUI `@main` 또는 `AppDelegate`)에서 호출
/// ```swift
/// @main
/// struct MyApp: App {
///     @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
///
///     init() {
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
///
/// - Note:
///   - `repositoryDefinitions`는 값 타입이므로,
///     클로저를 등록하기 전 반드시 로컬 복사(`var factoryCopy`)를 생성하여 사용해야 합니다.
///   - `makeAllModules()`를 호출하면 정의된 모든 클로저가 실행되어
///     `Module` 인스턴스가 만들어지고, 이후 `container.register(_:)`로 실제 DI 컨테이너에 주입됩니다.
public struct RepositoryModuleFactory: RepositoryModuleFactoryProtocol {
    // MARK: - 저장 프로퍼티

    /// 의존성 등록 헬퍼 객체(`RegisterModule`)입니다.
    public let registerModule = RegisterModule()

    /// Repository 모듈을 생성하는 클로저들의 배열입니다.
    /// 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
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


/// `RepositoryModuleFactory`는 `RepositoryModuleFactoryProtocol`을 채택하여
/// Repository 계층의 모듈 생성 및 등록을 담당하는 타입입니다.
///
/// - `registerModule`: 의존성 등록 헬퍼(`RegisterModule`) 인스턴스를 통해
///   Repository 모듈을 구성할 때 필요한 다른 의존성을 DI 컨테이너에 등록할 수 있습니다.
/// - `repositoryDefinitions`: Repository 모듈을 생성하는 클로저들의 배열로,
///   각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
/// - `makeAllModules()`: 내부 `repositoryDefinitions` 배열에 포함된 모든 클로저를 실행하여,
///   생성된 `Module` 인스턴스들의 배열을 반환합니다.
///
/// ## 사용 예시 (Swift 5.9 미만 / iOS 17.0 미지원)
///
/// 1) 프로토콜 및 기본 구현체 정의
/// ```swift
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
/// 2) `RepositoryModuleFactory` 확장하여 기본 정의 등록
/// ```swift
/// extension RepositoryModuleFactory {
///     /// 기본 Repository 의존성 정의를 설정합니다.
///     public mutating func registerDefaultDefinitions() {
///         let helper = registerModule  // self를 직접 캡처하지 않기 위해 복사
///         repositoryDefinitions = [
///             helper.makeDependency(AuthRepositoryProtocol.self) {
///                 DefaultAuthRepository()
///             }
///         ]
///     }
/// }
/// ```
///
/// 3) `AppDIContainer`에서 호출하여 DI 컨테이너에 모듈 등록
/// ```swift
/// extension AppDIContainer {
///     public func registerAuthRepository() async {
///         // 값 타입인 RepositoryModuleFactory 복사 (클로저 캡처 문제 방지)
///         var factoryCopy = RepositoryModuleFactory()
///
///         // 기본 정의 등록
///         factoryCopy.registerDefaultDefinitions()
///
///         // 생성된 모듈들을 비동기적으로 Container에 등록
///         await registerDependencies { container in
///             for module in factoryCopy.makeAllModules() {
///                 await container.register(module)
///             }
///         }
///     }
/// }
/// ```
///
/// 4) 앱 초기화 시점 (UIKit `AppDelegate`)에서 호출
/// ```swift
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
///
/// - Note:
///   - `repositoryDefinitions`는 값 타입이므로,
///     클로저를 등록하기 전 반드시 로컬 복사(`var factoryCopy`)를 생성하여 사용해야 합니다.
///   - `makeAllModules()`를 호출하면 정의된 모든 클로저가 실행되어
///     `Module` 인스턴스가 만들어지고, 이후 `container.register(_:)`로 실제 DI 컨테이너에 주입됩니다.
