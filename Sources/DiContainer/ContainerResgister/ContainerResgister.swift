//
//  ContainerResgister.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/27/25.
//

import Foundation

// 전역 `DependencyContainer`에서 의존성을 가져오는 프로퍼티 래퍼입니다.
///
/// - 설명:
///   - 제네릭 타입 `T`는 주입받을 의존성의 타입을 의미합니다.
///   - `keyPath`는 `DependencyContainer` 내부의 `T?` 타입 프로퍼티를 가리킵니다.
///   - `wrappedValue`에 접근할 때, 전역 컨테이너(`DependencyContainer.live`)에서
///     `keyPath`를 통해 의존성을 가져옵니다. 만약 해당 의존성이 nil이면,
///     `fatalError`를 통해 런타임에서 즉시 에러가 발생합니다.
///
#if swift(>=5.9)
@available(iOS 17.0, *)
@propertyWrapper
public struct ContainerResgister<T> {
  private let keyPath: KeyPath<DependencyContainer, T?>
  
  public var wrappedValue: T {
    guard let value = DependencyContainer.live[keyPath: keyPath] else {
      fatalError("No registered dependency found for \(T.self)")
    }
    return value
  }
  
  public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
    self.keyPath = keyPath
  }
}

#else
@propertyWrapper
public struct ContainerResgister<T> {
  private let keyPath: KeyPath<DependencyContainer, T?>
  
  public var wrappedValue: T {
    guard let value = DependencyContainer.live[keyPath: keyPath] else {
      fatalError("No registered dependency found for \(T.self)")
    }
    return value
  }
  
  public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
    self.keyPath = keyPath
  }
}
#endif
