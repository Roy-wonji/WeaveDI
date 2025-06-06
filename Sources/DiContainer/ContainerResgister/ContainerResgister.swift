//
//  ContainerResgister.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/27/25.
//

import Foundation

#if swift(>=5.9)
@available(iOS 17.0, *)
/// `ContainerResgister`는 전역 `DependencyContainer`에서 특정 타입의 의존성을 가져오는 프로퍼티 래퍼입니다.
///
/// - 제네릭 타입 `T`는 주입받을 의존성의 타입을 의미합니다.
/// - `keyPath`는 `DependencyContainer` 내부의 `T?` 타입 프로퍼티를 가리킵니다.
/// - `wrappedValue`에 접근할 때, 전역 컨테이너(`DependencyContainer.live`)에서
///   `keyPath`를 통해 의존성을 가져옵니다. 만약 해당 의존성이 `nil`이라면,
///   `fatalError`를 통해 런타임 시 즉시 에러가 발생합니다.
///
/// 예시:
/// ```swift
/// @ContainerResgister(\.networkService)
/// private var networkService: NetworkService
///
/// func fetchData() {
///     networkService.request(...)  // 전역 컨테이너에 등록된 NetworkService 인스턴스를 사용
/// }
/// ```
@propertyWrapper
public struct ContainerResgister<T> {
    // MARK: - 저장 프로퍼티

    /// `DependencyContainer` 내부의 `T?` 프로퍼티를 가리키는 KeyPath.
    private let keyPath: KeyPath<DependencyContainer, T?>

    // MARK: - 초기화

    /// KeyPath를 통해 주입받을 프로퍼티를 설정합니다.
    ///
    /// - Parameter keyPath: `DependencyContainer`의 `T?` 타입 프로퍼티를 가리키는 KeyPath.
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
    }

    // MARK: - 래퍼된 값

    /// 전역 `DependencyContainer.live`에서 `keyPath`를 통해 `T` 타입의 의존성을 가져옵니다.
    /// 만약 해당 의존성이 `nil`일 경우, 런타임에서 즉시 `fatalError`가 발생합니다.
    public var wrappedValue: T {
        guard let value = DependencyContainer.live[keyPath: keyPath] else {
            fatalError("No registered dependency found for \(T.self)")
        }
        return value
    }
}
#else
/// `ContainerResgister`는 전역 `DependencyContainer`에서 특정 타입의 의존성을 가져오는 프로퍼티 래퍼입니다.
///
/// - 제네릭 타입 `T`는 주입받을 의존성의 타입을 의미합니다.
/// - `keyPath`는 `DependencyContainer` 내부의 `T?` 타입 프로퍼티를 가리킵니다.
/// - `wrappedValue`에 접근할 때, 전역 컨테이너(`DependencyContainer.live`)에서
///   `keyPath`를 통해 의존성을 가져옵니다. 만약 해당 의존성이 `nil`이라면,
///   `fatalError`를 통해 런타임 시 즉시 에러가 발생합니다.
///
/// 예시:
/// ```swift
/// @ContainerResgister(\.networkService)
/// private var networkService: NetworkService
///
/// func fetchData() {
///     networkService.request(...)  // 전역 컨테이너에 등록된 NetworkService 인스턴스를 사용
/// }
/// ```
@propertyWrapper
public struct ContainerResgister<T> {
    // MARK: - 저장 프로퍼티

    /// `DependencyContainer` 내부의 `T?` 프로퍼티를 가리키는 KeyPath.
    private let keyPath: KeyPath<DependencyContainer, T?>

    // MARK: - 초기화

    /// KeyPath를 통해 주입받을 프로퍼티를 설정합니다.
    ///
    /// - Parameter keyPath: `DependencyContainer`의 `T?` 타입 프로퍼티를 가리키는 KeyPath.
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
    }

    // MARK: - 래퍼된 값

    /// 전역 `DependencyContainer.live`에서 `keyPath`를 통해 `T` 타입의 의존성을 가져옵니다.
    /// 만약 해당 의존성이 `nil`일 경우, 런타임에서 즉시 `fatalError`가 발생합니다.
    public var wrappedValue: T {
        guard let value = DependencyContainer.live[keyPath: keyPath] else {
            fatalError("No registered dependency found for \(T.self)")
        }
        return value
    }
}
#endif
