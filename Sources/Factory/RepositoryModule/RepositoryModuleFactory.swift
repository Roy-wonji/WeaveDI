//
//  RepositoryModuleFactory.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//


import Foundation

/// `RepositoryModuleFactory`는 `RepositoryModuleFactoryProtocol`을 채택하여
/// Repository 계층의 모듈 생성 및 등록을 담당합니다.
///
/// - `registerModule`: 의존성 등록 헬퍼(`RegisterModule`) 인스턴스를 통해
///   Repository 모듈을 구성할 때 필요한 다른 의존성을 DI 컨테이너에 등록할 수 있습니다.
/// - `repositoryDefinitions`: Repository 모듈을 생성하는 클로저들의 배열.
///   각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
/// - `makeAllModules()`: 내부 `repositoryDefinitions`의 모든 클로저를 실행하여
///   생성된 `Module` 인스턴스 배열을 반환합니다.
///
/// ## 사용 예시
///
/// ### 1) 프로토콜 및 기본 구현체 정의
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
/// ### 2) 기본 의존성 등록
/// ```swift
/// extension RepositoryModuleFactory {
///     public mutating func registerDefaultDefinitions() {
///         let helper = registerModule
///         repositoryDefinitions = [
///             helper.makeDependency(AuthRepositoryProtocol.self) {
///                 DefaultAuthRepository()
///             }
///         ]
///     }
/// }
/// ```
///
/// ### 3) DI 컨테이너에 등록
/// ```swift
/// extension AppDIContainer {
///     public func registerAuthRepository() async {
///         var factoryCopy = RepositoryModuleFactory()
///         factoryCopy.registerDefaultDefinitions()
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
/// ### 4) 앱 초기화 시점에서 호출
/// #### SwiftUI
/// ```swift
/// @main
/// struct MyApp: App {
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
/// #### UIKit
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
///   - `RepositoryModuleFactory`는 값 타입이므로, 클로저 캡처 문제를 피하려면 반드시
///     `var factoryCopy`로 복사하여 사용해야 합니다.
///   - `makeAllModules()` 호출 시 모든 의존성이 생성되며, 이후 `container.register(_:)`로 주입됩니다.
public struct RepositoryModuleFactory:  RepositoryModuleFactoryProtocol {
  // MARK: - 저장 프로퍼티
  
  /// 의존성 등록 헬퍼 객체
  public let registerModule = RegisterModule()
  
  /// Repository 모듈을 생성하는 클로저 배열
  public var repositoryDefinitions: [() -> Module]
  
  // MARK: - 초기화
  
  /// 생성자
  /// - Parameter repositoryDefinitions: 초기 모듈 생성 클로저 배열 (기본값: 빈 배열)
  public init(repositoryDefinitions: [() -> Module] = []) {
    self.repositoryDefinitions = repositoryDefinitions
  }
  
  // MARK: - 메서드
  
  /// 모든 Repository 모듈 생성
  /// - Returns: 생성된 `Module` 인스턴스 배열
  public func makeAllModules() -> [Module] {
    repositoryDefinitions.map { $0() }
  }
}
