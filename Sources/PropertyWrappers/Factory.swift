//
//  Factory.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/24/25.
//

import Foundation

// MARK: - Factory 프로퍼티 래퍼

/// ``FactoryValues`` 로부터 특정 팩토리 인스턴스를 주입받는 프로퍼티 래퍼입니다.
///
/// ## 개요
///
/// `@Factory`는 `FactoryValues`의 특정 프로퍼티(KeyPath로 지정)를 읽고/쓰는
/// 가벼운 팩토리 주입 도구입니다. 팩토리 인스턴스 자체를 관리하며,
/// 런타임에 팩토리를 교체할 수 있는 유연성을 제공합니다.
///
/// ## 핵심 특징
///
/// ### 🏭 팩토리 관리
/// - **런타임 교체**: 팩토리 인스턴스를 런타임에 동적 교체 가능
/// - **실시간 참조**: `FactoryValues.current`를 통한 최신 팩토리 참조
/// - **타입 안전성**: KeyPath 기반 타입 안전한 팩토리 접근
///
/// ### 🔄 동적 설정
/// - **테스트 환경**: 테스트용 Mock 팩토리로 쉽게 교체
/// - **A/B 테스트**: 다양한 팩토리 구현체 간 전환
/// - **환경별 설정**: Development/Staging/Production 환경별 팩토리
///
/// ### 🔒 동시성 안전성
/// - **Thread-safe 접근**: NSLock 기반 동시성 안전성 보장
/// - **Actor 호환**: Swift Concurrency와 호환되는 nonisolated 접근
/// - **메모리 안전성**: 자동 메모리 관리 및 참조 안전성
///
/// ## 사용 예시
///
/// ### 기본 사용법
/// ```swift
/// final class MyViewModel {
///     @Factory(\.repositoryFactory)
///     var repositoryFactory: RepositoryModuleFactory
///
///     @Factory(\.useCaseFactory)
///     var useCaseFactory: UseCaseModuleFactory
///
///     func configureServices() {
///         // 팩토리를 사용해서 모듈 생성
///         let repositories = repositoryFactory.makeAllModules()
///         let useCases = useCaseFactory.makeAllModules()
///
///         // 각 모듈을 등록
///         repositories.forEach { await $0.register() }
///         useCases.forEach { await $0.register() }
///     }
/// }
/// ```
///
/// ### 런타임 팩토리 교체
/// ```swift
/// // 프로덕션 환경
/// FactoryValues.current.repositoryFactory = ProductionRepositoryModuleFactory()
///
/// // 테스트 환경에서 Mock 팩토리로 교체
/// FactoryValues.current.repositoryFactory = MockRepositoryModuleFactory()
///
/// final class TestableService {
///     @Factory(\.repositoryFactory)
///     var factory: RepositoryModuleFactory  // 자동으로 최신 팩토리 참조
/// }
/// ```
///
/// ### 환경별 설정
/// ```swift
/// final class AppConfigurationManager {
///     static func configureDevelopmentFactories() {
///         FactoryValues.current = FactoryValues(
///             repositoryFactory: DevelopmentRepositoryModuleFactory(),
///             useCaseFactory: DevelopmentUseCaseModuleFactory(),
///             scopeFactory: DevelopmentScopeModuleFactory()
///         )
///     }
///
///     static func configureProductionFactories() {
///         FactoryValues.current = FactoryValues(
///             repositoryFactory: ProductionRepositoryModuleFactory(),
///             useCaseFactory: ProductionUseCaseModuleFactory(),
///             scopeFactory: ProductionScopeModuleFactory()
///         )
///     }
/// }
/// ```
///
/// ## @Factory vs @Inject 비교
///
/// | 특징 | @Factory | @Inject |
/// |------|----------|---------|
/// | **목적** | 팩토리 인스턴스 주입 | 의존성 인스턴스 주입 |
/// | **관리 대상** | FactoryValues | UnifiedDI |
/// | **교체 가능성** | 런타임 동적 교체 | 등록 시점 고정 |
/// | **사용 사례** | 팩토리 패턴, A/B 테스트 | 일반적인 DI |
/// | **성능** | 가벼움 (직접 참조) | 해결 오버헤드 |
///
/// ## 마이그레이션 가이드
///
/// ### 1.x에서 2.x로
/// ```swift
/// // 1.x (기존)
/// @Factory(\.repositoryFactory) var factory: RepositoryFactory
///
/// // 2.x (개선됨)
/// @Factory(\.repositoryFactory) var factory: RepositoryModuleFactory
/// ```
@propertyWrapper
public struct Factory<T> {
  
  // MARK: - 프로퍼티
  
  /// ``FactoryValues`` 내에서 `T` 타입 팩토리를 가리키는 KeyPath.
  private let keyPath: WritableKeyPath<FactoryValues, T>
  
  // MARK: - Wrapped Value
  
  /// 저장된 keyPath를 사용해 ``FactoryValues/current`` 로부터 값을 반환합니다.
  ///
  /// 새로운 값을 할당하면 전역 ``FactoryValues/current`` 값이 갱신됩니다.
  public var wrappedValue: T {
    get { FactoryValues.current[keyPath: keyPath] }
    set { FactoryValues.current[keyPath: keyPath] = newValue }
  }
  
  // MARK: - 초기화
  
  /// 주어진 KeyPath를 참조하는 프로퍼티 래퍼를 생성합니다.
  ///
  /// - Parameter keyPath: ``FactoryValues`` 내의 팩토리를 가리키는 KeyPath.
  ///
  /// - 예시:
  /// ```swift
  /// @Factory(\.repositoryFactory) var repositoryFactory: RepositoryFactory
  /// ```
  public init(_ keyPath: WritableKeyPath<FactoryValues, T>) {
    self.keyPath = keyPath
  }
}
