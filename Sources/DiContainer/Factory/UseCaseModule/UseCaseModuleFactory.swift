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

// MARK: - UseCaseModuleFactory

/// `UseCaseModuleFactory`는 ``UseCaseModuleFactoryProtocol``을 채택한 **Use Case 계층 모듈 팩토리**입니다.
///
/// # 개요
/// - Use Case 계층의 모듈을 생성하고 DI 컨테이너에 등록하는 역할을 담당합니다.
/// - `registerModule`: Repository 등 외부 의존성을 등록하기 위한 헬퍼 객체
/// - `useCaseDefinitions`: Use Case 인스턴스를 생성하는 클로저 배열
///   - 각 클로저는 호출 시 ``Module``을 반환
///   - 기본 구현은 빈 배열이며, 앱 측에서 `extension`을 통해 재정의해야 합니다.
///
/// ## Concurrency
/// - `actor`로 정의되어 있어, 동시성 환경에서 안전하게 호출 가능합니다.
/// - 단, `useCaseDefinitions`는 값 복사를 통해 캡처 문제를 방지하는 것이 권장됩니다.
///
/// ## Example
///
/// ### 1. Use Case 프로토콜 및 구현체 정의
/// ```swift
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
///         await repository.login(user: user, password: password)
///     }
/// }
/// ```
///
/// ### 2. Use Case 팩토리 확장
/// ```swift
/// extension UseCaseModuleFactory {
///     public var useCaseDefinitions: [() -> Module] {
///         let helper = registerModule
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
/// ### 3. AppDIContainer 확장
/// ```swift
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
/// ### 4. 앱 초기화 시점에서 등록
/// ```swift
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
public actor UseCaseModuleFactory: @preconcurrency UseCaseModuleFactoryProtocol {
  
  // MARK: - Properties
  
  /// 의존성 등록을 담당하는 헬퍼 객체.
  public let registerModule = RegisterModule()
  
  /// Use Case 모듈을 생성하는 클로저 배열.
  ///
  /// - Note: 앱에서 `extension`을 통해 재정의해야 합니다.
  public var useCaseDefinitions: [() -> Module] {
    return []
  }
  
  // MARK: - Init
  
  /// 기본 생성자.
  /// - 앱 측에서 `extension`을 통해 `useCaseDefinitions`를 확장하여 사용합니다.
  public init() {}
}
