//
//  Factory.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/24/25.
//

import Foundation

#if swift(>=5.9)
@available(iOS 17.0, *)

@propertyWrapper
public struct Factory<T> {
  /// FactoryValues 내에서 T 타입의 Factory 인스턴스를 조회하고 수정하기 위한 WritableKeyPath
  private let keyPath: WritableKeyPath<FactoryValues, T>
  
  /// wrappedValue는 매번 FactoryValues.current에서 keyPath를 통해 해당 Factory 인스턴스를 읽어오거나 수정합니다.
  public var wrappedValue: T {
    get { FactoryValues.current[keyPath: keyPath] }
    set { FactoryValues.current[keyPath: keyPath] = newValue }
  }
  
  /// 초기화 시, 주입받을 Factory 인스턴스가 저장된 WritableKeyPath를 지정합니다.
  /// 예시: @Factory(\.repositoryFactory)
  public init(_ keyPath: WritableKeyPath<FactoryValues, T>) {
    self.keyPath = keyPath
  }
}
#else
@propertyWrapper
public struct Factory<T> {
  /// FactoryValues 내에서 T 타입의 Factory 인스턴스를 조회하고 수정하기 위한 WritableKeyPath
  private let keyPath: WritableKeyPath<FactoryValues, T>
  
  /// wrappedValue는 매번 FactoryValues.current에서 keyPath를 통해 해당 Factory 인스턴스를 읽어오거나 수정합니다.
  public var wrappedValue: T {
    get { FactoryValues.current[keyPath: keyPath] }
    set { FactoryValues.current[keyPath: keyPath] = newValue }
  }
  
  /// 초기화 시, 주입받을 Factory 인스턴스가 저장된 WritableKeyPath를 지정합니다.
  /// 예시: @Factory(\.repositoryFactory)
  public init(_ keyPath: WritableKeyPath<FactoryValues, T>) {
    self.keyPath = keyPath
  }
}
#endif

