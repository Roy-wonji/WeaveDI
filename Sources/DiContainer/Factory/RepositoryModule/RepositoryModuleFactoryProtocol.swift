//
//  RepositoryModuleFactoryProtocol.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

/// RepositoryModuleFactoryProtocol은 Repository 모듈을 생성하는 기본 인터페이스를 정의합니다.
/// 이 프로토콜을 채택하는 타입은 의존성 등록 헬퍼 객체(registerModule)와,
/// Repository 모듈을 생성하는 클로저 배열(repositoryDefinitions), 그리고 이 클로저들을 실행하여 모듈들을 생성하는 기능을 제공해야 합니다.
///
#if swift(>=5.9)
@available(iOS 17.0, *)
public protocol RepositoryModuleFactoryProtocol {
  /// 의존성 등록을 위한 헬퍼 객체.
  /// 이 객체는 Repository 모듈 생성에 필요한 의존성들을 등록하는 역할을 수행합니다.
  var registerModule: RegisterModule { get }
  
  /// Repository 모듈을 생성하는 클로저들의 배열.
  /// 각 클로저는 호출 시에 Module 인스턴스를 생성하여 반환합니다.
  var repositoryDefinitions: [() -> Module] { get }
  
  /// repositoryDefinitions 배열에 있는 모든 클로저를 실행하여, 생성된 Module 인스턴스들의 배열을 반환합니다.
  func makeAllModules() -> [Module]
}


#else
public protocol RepositoryModuleFactoryProtocol {
  var registerModule: RegisterModule { get }
  var repositoryDefinitions: [() -> Module] { get }
  func makeAllModules() -> [Module]
}
#endif


/// RepositoryModuleFactoryProtocol의 기본 구현을 제공하는 extension입니다.
/// makeAllModules() 메서드는 repositoryDefinitions 배열에 있는 모든 클로저를 순회하며 실행합니다.
#if swift(>=5.9)
@available(iOS 17.0, *)
public extension RepositoryModuleFactoryProtocol {
  func makeAllModules() -> [Module] {
    // 각 클로저를 호출하여 생성된 모듈들을 배열로 만듭니다.
    repositoryDefinitions.map { $0() }
  }
}
#else

/// RepositoryModuleFactoryProtocol의 기본 구현을 제공하는 extension입니다.
/// makeAllModules() 메서드는 repositoryDefinitions 배열에 있는 모든 클로저를 순회하며 실행합니다.
public extension RepositoryModuleFactoryProtocol {
  func makeAllModules() -> [Module] {
    // 각 클로저를 호출하여 생성된 모듈들을 배열로 만듭니다.
    repositoryDefinitions.map { $0() }
  }
}
#endif
