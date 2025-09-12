//
//  ScopeModuleFactoryProtocol.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation

// MARK: - ScopeModuleFactoryProtocol

/// DependencyScope 계층의 모듈(의존성)을 **생성**하고 **등록**하기 위한 표준 인터페이스입니다.
///
/// ## Overview
/// 구현 타입은 다음을 제공합니다:
/// 1. ``registerModule`` — Scope 모듈 생성 시 필요한 의존성 등록 헬퍼(`RegisterModule`)
/// 2. ``scopeDefinitions`` — `Module`을 생성하는 **클로저 배열**
/// 3. ``makeAllModules()`` — 위 클로저들을 실행해 **`Module` 인스턴스 배열**을 반환
///
/// ### 역할
/// - ``registerModule``를 활용해, DependencyScope가 의존하는 다른 구성 요소를 **선언적으로 등록**합니다.
/// - ``scopeDefinitions``에 `Module` 생성 클로저를 **나열**하면, 등록 대상이 명확해지고 테스트가 쉬워집니다.
/// - ``makeAllModules()``는 정의한 모든 클로저를 실행해 실제 `Module` 인스턴스를 생성합니다.
///
/// ## Usage
/// ### 1) DependencyScope 및 구현체 정의
/// ```swift
/// struct NetworkScope: DependencyScope {
///   typealias Dependencies = EmptyDependencies
///   typealias Provides = NetworkServiceProtocol
///   
///   static func validate() -> Bool { true }
/// }
///
/// struct DefaultNetworkService: NetworkServiceProtocol {
///   func request(_ url: String) async -> Data {
///     // 실제 네트워크 요청 로직
///     return Data()
///   }
/// }
/// ```
///
/// ### 2) 팩토리 구현
/// `makeScopedDependency(scope:factory:)`로 스코프 기반 모듈을 선언합니다.
/// ```swift
/// struct NetworkScopeModuleFactory: ScopeModuleFactoryProtocol {
///   let registerModule = RegisterModule() // 값 복사로 캡처 이슈 방지
///
///   var scopeDefinitions: [() -> Module] {
///     [
///       registerModule.makeScopedDependency(
///         scope: NetworkScope.self,
///         factory: { DefaultNetworkService() }
///       )
///     ]
///   }
/// }
/// ```
///
/// ### 3) 컨테이너에 일괄 등록
/// ```swift
/// extension AppDIContainer {
///   public func registerNetworkScope() async {
///     let factoryCopy = NetworkScopeModuleFactory() // 값 복사 권장
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
///     Task { await AppDIContainer.shared.registerNetworkScope() }
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
///     Task { await AppDIContainer.shared.registerNetworkScope() }
///     return true
///   }
/// }
/// ```
///
/// ## Best Practices
/// - **정의/등록 분리:** 팩토리는 "정의", 컨테이너는 "등록"에 집중하세요.
/// - **캡처 최소화:** `let helper = registerModule`처럼 값 복사를 활용하면 클로저 캡처 문제를 줄일 수 있습니다.
/// - **스코프 검증:** `DependencyScope.validate()`를 통해 의존성 유효성을 런타임에 확인하세요.
/// - **계층적 구조:** 상위 스코프를 먼저 등록한 후 하위 스코프를 등록하세요.
///
/// ## See Also
/// - ``RegisterModule``
/// - ``DependencyScope``
/// - ``Module``
/// - ``RepositoryModuleFactoryProtocol``
public protocol ScopeModuleFactoryProtocol {
  // MARK: - Properties
  
  /// Scope 모듈 생성 시 사용하는 의존성 등록 헬퍼(`RegisterModule`).
  var registerModule: RegisterModule { get }
  
  /// DependencyScope 모듈을 생성하는 **클로저**들의 배열.
  /// 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
  var scopeDefinitions: [() -> Module] { get }
  
  // MARK: - Methods
  
  /// ``scopeDefinitions`` 배열의 모든 클로저를 실행하여,
  /// 생성된 `Module` 인스턴스들의 배열을 반환합니다.
  ///
  /// - Returns: 생성된 `Module` 인스턴스 배열.
  func makeAllModules() -> [Module]
}

// MARK: - 기본 구현
public extension ScopeModuleFactoryProtocol {
  /// ``scopeDefinitions``의 모든 클로저를 호출하여
  /// 생성된 `Module` 배열을 반환합니다.
  func makeAllModules() -> [Module] {
    scopeDefinitions.map { $0() }
  }
}