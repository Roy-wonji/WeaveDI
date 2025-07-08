//
//  Factory.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/24/25.
//

import Foundation

/// `Factory` 프로퍼티 래퍼는 `FactoryValues` 내에서 특정 타입의 팩토리 인스턴스를 주입받기 위해 사용됩니다.
///
/// - 제네릭 타입 `T`는 주입받을 팩토리 인스턴스의 타입을 나타냅니다.
/// - `keyPath`는 `FactoryValues.current`에서 해당 팩토리 인스턴스를 조회 또는 수정할 수 있는 `WritableKeyPath`를 가리킵니다.
/// - `wrappedValue` 프로퍼티에 접근할 때마다 `FactoryValues.current`에서 `keyPath`를 통해 값을 읽거나 쓸 수 있습니다.
///
/// ## 사용 예시
/// ```swift
/// import Foundation
///
/// // 1) FactoryValues 정의
/// struct FactoryValues {
///     var repositoryFactory: RepositoryFactory
///     var useCaseFactory: UseCaseFactory
///
///     // 글로벌로 사용되는 FactoryValues 인스턴스
///     nonisolated(unsafe) static var current = FactoryValues(
///         repositoryFactory: DefaultRepositoryFactory(),
///         useCaseFactory: DefaultUseCaseFactory()
///     )
/// }
///
/// // 2) ViewModel 또는 클래스 내에서
/// class MyViewModel {
///     @Factory(\.repositoryFactory)
///     var repositoryFactory: RepositoryFactory
///
///     @Factory(\.useCaseFactory)
///     var useCaseFactory: UseCaseFactory
///
///     func fetchData() {
///         // repositoryFactory.makeRepository() 등을 호출하여 인스턴스 생성
///         let repo = repositoryFactory.makeRepository()
///         let useCase = useCaseFactory.makeUseCase(with: repo)
///         // ...
///     }
/// }
/// ```
@propertyWrapper
public struct Factory<T> {
    // MARK: - 저장 프로퍼티

    /// `FactoryValues` 내에서 `T` 타입의 팩토리 인스턴스를 조회 및 수정하기 위한 KeyPath.
    private let keyPath: WritableKeyPath<FactoryValues, T>

    // MARK: - 래퍼된 값

    /// `FactoryValues.current`에서 `keyPath`를 통해 해당 팩토리 인스턴스를 가져오거나 설정합니다.
    public var wrappedValue: T {
        get { FactoryValues.current[keyPath: keyPath] }
        set { FactoryValues.current[keyPath: keyPath] = newValue }
    }

    // MARK: - 초기화

    /// 주입받을 팩토리 인스턴스가 저장된 `WritableKeyPath`를 지정합니다.
    ///
    /// - Parameter keyPath: `FactoryValues`의 `T` 타입 프로퍼티를 가리키는 `WritableKeyPath`.
    /// - Note: 사용 예시처럼 `@Factory(\.repositoryFactory)` 형태로 사용합니다.
    public init(_ keyPath: WritableKeyPath<FactoryValues, T>) {
        self.keyPath = keyPath
    }
}

/// `Factory` 프로퍼티 래퍼는 `FactoryValues` 내에서 특정 타입의 팩토리 인스턴스를 주입받기 위해 사용됩니다.
///
/// - 제네릭 타입 `T`는 주입받을 팩토리 인스턴스의 타입을 나타냅니다.
/// - `keyPath`는 `FactoryValues.current`에서 해당 팩토리 인스턴스를 조회 또는 수정할 수 있는 `WritableKeyPath`를 가리킵니다.
/// - `wrappedValue` 프로퍼티에 접근할 때마다 `FactoryValues.current`에서 `keyPath`를 통해 값을 읽거나 쓸 수 있습니다.
///
/// ## 사용 예시
/// ```swift
/// import Foundation
///
/// // 1) FactoryValues 정의
/// struct FactoryValues {
///     var repositoryFactory: RepositoryFactory
///     var useCaseFactory: UseCaseFactory
///
///     // 글로벌로 사용되는 FactoryValues 인스턴스
///     static var current = FactoryValues(
///         repositoryFactory: DefaultRepositoryFactory(),
///         useCaseFactory: DefaultUseCaseFactory()
///     )
/// }
///
/// // 2) ViewModel 또는 클래스 내에서
/// class MyViewModel {
///     @Factory(\.repositoryFactory)
///     var repositoryFactory: RepositoryFactory
///
///     @Factory(\.useCaseFactory)
///     var useCaseFactory: UseCaseFactory
///
///     func fetchData() {
///         // repositoryFactory.makeRepository() 등을 호출하여 인스턴스 생성
///         let repo = repositoryFactory.makeRepository()
///         let useCase = useCaseFactory.makeUseCase(with: repo)
///         // ...
///     }
/// }
/// ```

