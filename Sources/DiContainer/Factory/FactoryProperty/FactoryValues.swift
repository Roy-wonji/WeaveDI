//
//  FactoryValues.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/24/25.
//

import Foundation

#if swift(>=5.9)
@available(iOS 17.0, *)
public struct FactoryValues {
  /// Repository 모듈 팩토리 기본 인스턴스
  public var repositoryFactory: RepositoryModuleFactory = RepositoryModuleFactory()
  
  /// UseCase 모듈 팩토리 기본 인스턴스
  public var useCaseFactory: UseCaseModuleFactory = UseCaseModuleFactory()
  

  public init() {}
  
  /// 전역으로 사용 가능한 FactoryValues 인스턴스
  nonisolated(unsafe) static var current = FactoryValues()
}

#else
public struct FactoryValues {
  /// Repository 모듈 팩토리 기본 인스턴스
  public var repositoryFactory: RepositoryModuleFactory = RepositoryModuleFactory()
  
  /// UseCase 모듈 팩토리 기본 인스턴스
  public var useCaseFactory: UseCaseModuleFactory = UseCaseModuleFactory()
  
  public init() {}
  
  /// 전역으로 사용 가능한 FactoryValues 인스턴스
  nonisolated(unsafe) static var current = FactoryValues()
}
#endif
