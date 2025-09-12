//
//  FactoryValues.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/24/25.
//

import Foundation

// MARK: - FactoryValues

/// A global container of factories used across the application.
///
/// # Overview
/// `FactoryValues`는 앱 전역에서 사용하는 다양한 모듈 **Factory 인스턴스**를
/// 한곳에서 관리하기 위한 경량 컨테이너입니다. 각 레이어(Repository, UseCase 등)의
/// 기본 Factory를 보관하고, 필요 시 런타임에 교체 할 수 있습니다.
///
/// 이 타입은 **전역 싱글턴**(`FactoryValues.current`) 접근을 제공합니다.
/// 동기/비동기 컨텍스트에서 모두 접근 가능하도록 `nonisolated(unsafe)`로 노출됩니다.
///
/// > Tip:
/// > 테스트나 A/B 구성 시 `FactoryValues.current`를 교체해 의존성 주입을 간소화할 수 있습니다.
///
/// ## Concurrency
/// `current`는 `nonisolated(unsafe)`로 선언되어 액터 격리를 우회합니다.
/// 멀티스레드 환경에서 **경합(race)**을 피하려면 앱 차원에서 교체 시점을 관리하거나
/// 별도의 동기화 전략을 적용하세요.
///
/// ## Availability
/// - Swift 5.9+
/// - iOS 17.0+
///
/// ## Topics
/// - ``repositoryFactory``
/// - ``useCaseFactory``
/// - ``scopeFactory``
/// - ``current``
///
/// - Example: 기본 사용
/// ```swift
/// // 기본 팩토리 사용
/// let repo = FactoryValues.current.repositoryFactory
/// let useCase = FactoryValues.current.useCaseFactory
/// ```
///
/// - Example: 런타임 교체
/// ```swift
/// // 커스텀 팩토리로 교체
/// FactoryValues.current.repositoryFactory = CustomRepositoryModuleFactory()
/// FactoryValues.current.useCaseFactory = CustomUseCaseModuleFactory()
/// ```
///
/// - Example: Property Wrapper로 주입 (@Factory는 사용자 정의라고 가정)
/// ```swift
/// final class MyViewModel {
///   @Factory(\.repositoryFactory) var repositoryFactory: RepositoryModuleFactory
///   @Factory(\.useCaseFactory)     var useCaseFactory: UseCaseModuleFactory
///
///   func configure() {
///     let repos = repositoryFactory.makeAllModules()
///     let uses  = useCaseFactory.makeAllModules()
///     // ...
///   }
/// }
/// ```
public struct FactoryValues {
  
  // MARK: Factories
  
  /// The default instance of repository-layer factory.
  ///
  /// 기본 Repository 팩토리 인스턴스입니다. 필요 시 런타임에 교체할 수 있습니다.
  public var repositoryFactory: RepositoryModuleFactory
  
  /// The default instance of use-case–layer factory.
  ///
  /// 기본 UseCase 팩토리 인스턴스입니다. 필요 시 런타임에 교체할 수 있습니다.
  public var useCaseFactory: UseCaseModuleFactory
  
  /// The default instance of dependency-scope factory.
  ///
  /// 기본 DependencyScope 팩토리 인스턴스입니다. 필요 시 런타임에 교체할 수 있습니다.
  public var scopeFactory: ScopeModuleFactory
  
  // MARK: Init
  
  /// Creates a new set of factory values.
  ///
  /// - Parameters:
  ///   - repositoryFactory: 기본 Repository 모듈 팩토리. 기본값은 `RepositoryModuleFactory()`.
  ///   - useCaseFactory: 기본 UseCase 모듈 팩토리. 기본값은 `UseCaseModuleFactory()`.
  ///   - scopeFactory: 기본 DependencyScope 모듈 팩토리. 기본값은 `ScopeModuleFactory()`.
  public init(
    repositoryFactory: RepositoryModuleFactory = RepositoryModuleFactory(),
    useCaseFactory: UseCaseModuleFactory = UseCaseModuleFactory(),
    scopeFactory: ScopeModuleFactory = ScopeModuleFactory()
  ) {
    self.repositoryFactory = repositoryFactory
    self.useCaseFactory = useCaseFactory
    self.scopeFactory = scopeFactory
  }
  
  // MARK: Global Singleton
  
  /// The global, mutable set of factory values.
  ///
  /// 액터 격리 제약 없이 접근하기 위해 `nonisolated(unsafe)`로 정의되어 있습니다.
  /// 스레드 안전성은 호출자가 보장해야 합니다.
  nonisolated(unsafe) public static var current = FactoryValues()
}
