//
//  UseCaseModuleFactoryProtocol.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

// MARK: - UseCaseModuleFactoryProtocol

/// Use Case 계층의 모듈을 **생성**하고 **등록**하기 위한 표준 인터페이스입니다.
/// 구현 타입은 다음을 제공합니다:
/// 1. ``registerModule``: Use Case 모듈 생성 시 필요한 의존성을 등록하는 헬퍼(`RegisterModule`)
/// 2. ``useCaseDefinitions``: `Module` 생성 **클로저**의 목록
/// 3. ``makeAllModules()``: 위 클로저들을 실행해 **`Module` 인스턴스 배열**을 반환
///
/// ## Overview
/// - `registerModule`을 통해, Use Case가 의존하는 Repository 등을 **DI 컨테이너에 선언적으로 등록**할 수 있습니다.
/// - `useCaseDefinitions`에 모듈을 **목록 형태**로 정의하면, 팩토리의 책임과 의존성 구성이 명확해집니다.
/// - ``makeAllModules()``는 정의된 모든 모듈을 **실제 인스턴스**로 변환하여, 등록 루프에서 바로 사용할 수 있게 합니다.
///
/// ## Usage
/// ### 1) Use Case/Repository 정의
/// ```swift
/// protocol AuthUseCaseProtocol {
///   func authenticate(user: String, password: String) async -> Bool
/// }
///
/// struct DefaultAuthUseCase: AuthUseCaseProtocol {
///   private let repository: AuthRepositoryProtocol
///   init(repository: AuthRepositoryProtocol) { self.repository = repository }
///
///   func authenticate(user: String, password: String) async -> Bool {
///     await repository.login(user: user, password: password)
///   }
/// }
/// ```
///
/// ### 2) 팩토리에서 모듈 정의
/// `RegisterModule.makeUseCaseWithRepository`를 이용해 **Repository 자동 주입**:
/// ```swift
/// extension UseCaseModuleFactory {
///   public var useCaseDefinitions: [() -> Module] {
///     let helper = registerModule // self 직접 캡처 회피
///     return [
///       helper.makeUseCaseWithRepository(
///         AuthUseCaseProtocol.self,
///         repositoryProtocol: AuthRepositoryProtocol.self,
///         repositoryFallback: DefaultAuthRepository() // (선택) 미등록 시 기본 Repo
///       ) { repo in
///         DefaultAuthUseCase(repository: repo)
///       }
///     ]
///   }
/// }
/// ```
///
/// > Tip: `repositoryFallback`이 **없어도** 동작하게 구성하려면,
/// > `RegisterModule`의 `MissingRepoStrategy`를 `.useNoOp { ... }` 또는
/// > `.skipRegistration()`으로 사용하세요(크래시 없이 안전한 부트스트랩).
///
/// ### 3) 컨테이너에 일괄 등록
/// ```swift
/// extension AppDIContainer {
///   public func registerDefaultUseCaseModules() async {
///     let factoryCopy = self.useCaseFactory // 값 복사로 캡처 문제 방지
///     await registerDependencies { container in
///       for module in factoryCopy.makeAllModules() {
///         await container.register(module)
///       }
///     }
///   }
/// }
/// ```
///
/// ### 4) 앱 초기화 (SwiftUI / UIKit)
/// ```swift
/// // SwiftUI
/// @main
/// struct MyApp: App {
///   init() {
///     Task { await AppDIContainer.shared.registerDefaultUseCaseModules() }
///   }
///   var body: some Scene { WindowGroup { ContentView() } }
/// }
/// ```
///
/// ```swift
/// // UIKit AppDelegate
/// @main
/// class AppDelegate: UIResponder, UIApplicationDelegate {
///   func application(_ application: UIApplication,
///                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
///     Task { await AppDIContainer.shared.registerDefaultUseCaseModules() }
///     return true
///   }
/// }
/// ```
///
/// ## Best Practices
/// - **정의와 등록 분리**: 팩토리에서 “정의”, 컨테이너에서 “등록”을 수행해 책임을 분리하세요.
/// - **캡처 주의**: `useCaseDefinitions` 내부에서 `self`를 직접 캡처하지 말고 `let helper = registerModule`처럼 **값 복사**를 권장합니다.
/// - **안전한 부트스트랩**: 필수 Repo가 미등록일 수 있다면, `MissingRepoStrategy`로
///   `.useNoOp` 또는 `.skipRegistration`을 사용해 앱 중단 없이 진행하세요.
///
/// ## See Also
/// - ``RegisterModule``
/// - ``Module``
/// - `RegisterModule.MissingRepoStrategy` (no-op/skip 전략)
public protocol UseCaseModuleFactoryProtocol {
  // MARK: - Properties
  
  /// Use Case 모듈 생성 시 필요한 의존성을 등록하기 위한 헬퍼(`RegisterModule`).
  var registerModule: RegisterModule { get }
  
  /// Use Case 모듈을 생성하는 **클로저**들의 배열.
  /// 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
  var useCaseDefinitions: [() -> Module] { get }
  
  // MARK: - Methods
  
  /// ``useCaseDefinitions`` 배열의 모든 클로저를 실행하여,
  /// 생성된 `Module` 인스턴스들의 배열을 반환합니다.
  ///
  /// - Returns: 생성된 `Module` 인스턴스 배열.
  func makeAllModules() -> [Module]
}


/// # (레거시/하위 호환) 간단 예시
///
/// Swift 5.9 미만(iOS 17 미지원) 환경에서도 동일한 패턴으로 사용할 수 있습니다.
/// 필요시 async/await 없이 동기 팩토리로도 `Module` 생성이 가능합니다.
///
/// ```swift
/// protocol AuthUseCaseProtocol {
///   func authenticate(user: String, password: String) -> Bool
/// }
///
/// struct DefaultAuthUseCase: AuthUseCaseProtocol {
///   private let repository: AuthRepositoryProtocol
///   init(repository: AuthRepositoryProtocol) { self.repository = repository }
///
///   func authenticate(user: String, password: String) -> Bool {
///     repository.login(user: user, password: password)
///   }
/// }
///
/// extension UseCaseModuleFactory {
///   public var useCaseDefinitions: [() -> Module] {
///     let helper = registerModule
///     return [
///       helper.makeUseCaseWithRepository(
///         AuthUseCaseProtocol.self,
///         repositoryProtocol: AuthRepositoryProtocol.self,
///         repositoryFallback: DefaultAuthRepository()
///       ) { repo in
///         DefaultAuthUseCase(repository: repo)
///       }
///     ]
///   }
/// }
///
/// extension AppDIContainer {
///   public func registerDefaultUseCaseModules() async {
///     let factoryCopy = self.useCaseFactory
///     await registerDependencies { container in
///       for module in factoryCopy.makeAllModules() {
///         await container.register(module)
///       }
///     }
///   }
/// }
/// ```
public extension UseCaseModuleFactoryProtocol {
  /// `useCaseDefinitions` 배열의 모든 클로저를 호출하여,
  /// 생성된 `Module` 인스턴스 배열을 반환합니다.
  ///
  /// - Returns: 생성된 `Module` 인스턴스들의 배열.
  func makeAllModules() -> [Module] {
    useCaseDefinitions.map { $0() }
  }
}
