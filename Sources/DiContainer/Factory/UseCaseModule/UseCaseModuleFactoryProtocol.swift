//
//  UseCaseModuleFactoryProtocol.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

/// UseCaseModuleFactoryProtocol은 Use Case 모듈을 생성하기 위한 기본 인터페이스를 정의합니다.
/// 이 프로토콜을 채택하는 타입은 의존성 등록을 위한 registerModule,
/// 모듈 생성 클로저 배열인 useCaseDefinitions, 그리고 모든 모듈을 생성하는 makeAllModules()를 구현해야 합니다.
#if swift(>=5.9)
@available(iOS 17.0, *)
public protocol UseCaseModuleFactoryProtocol {
  /// 의존성 등록을 도와주는 헬퍼 객체
  var registerModule: RegisterModule { get }
  
  /// Use Case 모듈을 생성하는 클로저 배열
  /// 각 클로저는 호출 시에 Module 인스턴스를 반환합니다.
  var useCaseDefinitions: [() -> Module] { get }
  
  /// useCaseDefinitions 배열에 있는 모든 클로저를 실행하여, Module 인스턴스들의 배열을 반환합니다.
  func makeAllModules() -> [Module]
}

#else
public protocol UseCaseModuleFactoryProtocol {
  /// 의존성 등록을 도와주는 헬퍼 객체
  var registerModule: RegisterModule { get }
  
  /// Use Case 모듈을 생성하는 클로저 배열
  /// 각 클로저는 호출 시에 Module 인스턴스를 반환합니다.
  var useCaseDefinitions: [() -> Module] { get }
  
  /// useCaseDefinitions 배열에 있는 모든 클로저를 실행하여, Module 인스턴스들의 배열을 반환합니다.
  func makeAllModules() -> [Module]
}
#endif


/// 기본 구현을 제공하는 extension입니다.
/// 이 extension은 makeAllModules()의 기본 동작을 정의합니다.
#if swift(>=5.9)
@available(iOS 17.0, *)
public extension UseCaseModuleFactoryProtocol {
  func makeAllModules() -> [Module] {
    // 각 클로저를 호출하여 생성된 모듈들을 배열로 만듭니다.
    useCaseDefinitions.map { $0() }
  }
}
#else
public extension UseCaseModuleFactoryProtocol {
  func makeAllModules() -> [Module] {
    // 각 클로저를 호출하여 생성된 모듈들을 배열로 만듭니다.
    useCaseDefinitions.map { $0() }
  }
}
#endif

