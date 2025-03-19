//
//  Container.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation
import Combine

#if swift(>=5.9)
@available(iOS 17.0, *)
@Observable
public class Container {
  private var modules: [Module] = []
  
  public init() {}
  
  // 단일 모듈 등록
  @discardableResult
  public func register(_ module: Module) -> Self {
    modules.append(module)
    return self
  }
  
  // 트레일링 클로저 처리
  @discardableResult
  public func callAsFunction(_ block: () -> Void) -> Self {
    block() // 트레일링 클로저 실행
    return self
  }
  
  // 모든 모듈 등록 실행 (비동기)
  public func build() async {
    for module in modules {
      await module.register()
    }
  }
}
#else
public final class Container: ObservableObject {
  private var modules: [Module] = []
  
  public init() {}
  
  // 단일 모듈 등록
  @discardableResult
  public func register(_ module: Module) -> Self {
    modules.append(module)
    return self
  }
  
  // 트레일링 클로저 처리
  @discardableResult
  public func callAsFunction(_ block: () -> Void) -> Self {
    block() // 트레일링 클로저 실행
    return self
  }
  
  // 모든 모듈 등록 실행 (비동기)
  public func build() async {
    for module in modules {
      await module.register()
    }
  }
}
#endif
