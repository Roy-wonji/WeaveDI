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
/// # 개요
/// `Factory`는 `FactoryValues`의 특정 프로퍼티(KeyPath로 지정)를 읽고/쓰는
/// 가벼운 의존성 주입 도구입니다.
///
/// - 제네릭 타입 `T`는 주입받을 팩토리 인스턴스의 타입을 나타냅니다.
/// - `keyPath`는 `FactoryValues.current` 내의 해당 프로퍼티를 가리킵니다.
/// - `wrappedValue` 접근 시 `FactoryValues.current[keyPath:]`를 통해 **실시간 값**을 가져옵니다.
///
/// ## 동시성
/// - 내부적으로 `FactoryValues.current`를 사용하므로, 전역 상태를 변경할 경우
///   스레드 안전성은 호출자가 직접 보장해야 합니다.
/// - `nonisolated(unsafe)` 속성으로 노출된 `FactoryValues.current`를 읽기 때문에
///   동기/비동기 맥락에서 제약 없이 사용할 수 있습니다.
///
/// ## 사용 예시
///
/// ### FactoryValues 정의
/// ```swift
/// struct FactoryValues {
///     var repositoryFactory: RepositoryFactory
///     var useCaseFactory: UseCaseFactory
///
///     nonisolated(unsafe) static var current = FactoryValues(
///         repositoryFactory: DefaultRepositoryFactory(),
///         useCaseFactory: DefaultUseCaseFactory()
///     )
/// }
/// ```
///
/// ### ViewModel에서 주입
/// ```swift
/// final class MyViewModel {
///     @Factory(\.repositoryFactory)
///     var repositoryFactory: RepositoryFactory
///
///     @Factory(\.useCaseFactory)
///     var useCaseFactory: UseCaseFactory
///
///     func fetchData() {
///         let repo = repositoryFactory.makeRepository()
///         let useCase = useCaseFactory.makeUseCase(with: repo)
///         // ...
///     }
/// }
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
