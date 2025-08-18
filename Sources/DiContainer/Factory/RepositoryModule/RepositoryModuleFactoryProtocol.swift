//
//  RepositoryModuleFactoryProtocol.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

// MARK: - RepositoryModuleFactoryProtocol

/// Repository 계층의 모듈(의존성)을 **생성**하고 **등록**하기 위한 표준 인터페이스입니다.
///
/// ## Overview
/// 구현 타입은 다음을 제공합니다:
/// 1. ``registerModule`` — Repository 모듈 생성 시 필요한 의존성 등록 헬퍼(`RegisterModule`)
/// 2. ``repositoryDefinitions`` — `Module`을 생성하는 **클로저 배열**
/// 3. ``makeAllModules()`` — 위 클로저들을 실행해 **`Module` 인스턴스 배열**을 반환
///
/// ### 역할
/// - ``registerModule``를 활용해, Repository가 의존하는 다른 구성 요소를 **선언적으로 등록**합니다.
/// - ``repositoryDefinitions``에 `Module` 생성 클로저를 **나열**하면, 등록 대상이 명확해지고 테스트가 쉬워집니다.
/// - ``makeAllModules()``는 정의한 모든 클로저를 실행해 실제 `Module` 인스턴스를 생성합니다.
///
/// ## Usage
/// ### 1) 프로토콜 및 구현체 정의
/// ```swift
/// protocol AuthRepositoryProtocol {
///   func login(user: String, password: String) async -> Bool
/// }
///
/// struct DefaultAuthRepository: AuthRepositoryProtocol {
///   func login(user: String, password: String) async -> Bool {
///     // 실제 로그인 로직
///     return true
///   }
/// }
/// ```
///
/// ### 2) 팩토리 구현
/// `makeDependency(_:factory:)`로 `AuthRepositoryProtocol` → `DefaultAuthRepository` 매핑을 선언합니다.
/// ```swift
/// struct AuthRepositoryModuleFactory: RepositoryModuleFactoryProtocol {
///   let registerModule = RegisterModule() // 값 복사로 캡처 이슈 방지
///
///   var repositoryDefinitions: [() -> Module] {
///     [
///       registerModule.makeDependency(AuthRepositoryProtocol.self) {
///         DefaultAuthRepository()
///       }
///     ]
///   }
/// }
/// ```
///
/// ### 3) 컨테이너에 일괄 등록
/// ```swift
/// extension AppDIContainer {
///   public func registerAuthRepository() async {
///     var factoryCopy = AuthRepositoryModuleFactory() // 값 복사 권장
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
///   @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
///
///   init() {
///     Task { await AppDIContainer.shared.registerAuthRepository() }
///   }
///
///   var body: some Scene { WindowGroup { ContentView() } }
/// }
/// ```
///
/// ```swift
/// // UIKit AppDelegate
/// @main
/// class AppDelegate: UIResponder, UIApplicationDelegate {
///   func application(_ application: UIApplication,
///                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
///     Task { await AppDIContainer.shared.registerAuthRepository() }
///     return true
///   }
/// }
/// ```
///
/// ## Best Practices
/// - **정의/등록 분리:** 팩토리는 “정의”, 컨테이너는 “등록”에 집중하세요.
/// - **캡처 최소화:** `let helper = registerModule`처럼 값 복사를 활용하면 클로저 캡처 문제를 줄일 수 있습니다.
/// - **병렬 등록 고려:** 컨테이너가 스레드 세이프/actor라면, 여러 `Module`을 병렬 등록하여 부트 시간 단축.
/// - **레거시/테스트:** 동일한 팩토리에서 구현체만 바꿔 Mock/Live를 손쉽게 스위칭하십시오.
///
/// ## See Also
/// - ``RegisterModule``
/// - ``Module``
/// - ``UseCaseModuleFactoryProtocol``
public protocol RepositoryModuleFactoryProtocol {
  // MARK: - Properties
  
  /// Repository 모듈 생성 시 사용하는 의존성 등록 헬퍼(`RegisterModule`).
  var registerModule: RegisterModule { get }
  
  /// Repository 모듈을 생성하는 **클로저**들의 배열.
  /// 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
  var repositoryDefinitions: [() -> Module] { get }
  
  // MARK: - Methods
  
  /// ``repositoryDefinitions`` 배열의 모든 클로저를 실행하여,
  /// 생성된 `Module` 인스턴스들의 배열을 반환합니다.
  ///
  /// - Returns: 생성된 `Module` 인스턴스 배열.
  func makeAllModules() -> [Module]
}

// MARK: - 기본 구현
public extension RepositoryModuleFactoryProtocol {
  /// ``repositoryDefinitions``의 모든 클로저를 호출하여
  /// 생성된 `Module` 배열을 반환합니다.
  func makeAllModules() -> [Module] {
    repositoryDefinitions.map { $0() }
  }
}
