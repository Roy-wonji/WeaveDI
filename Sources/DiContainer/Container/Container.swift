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
/// `Container`는 모듈(의존성)을 등록하고, 이를 일괄적으로 실행(build)하는 역할을 하는 Observable 클래스입니다.

public actor Container {
  /// 등록된 모듈들을 보관하는 배열입니다.
  private var modules: [Module] = []
  
  /// 기본 초기화 메서드입니다. 인스턴스 생성 시 모듈 배열은 빈 배열로 시작합니다.
  public init() {}
  
  /// 단일 모듈을 등록합니다.
  ///
  /// - Parameter module: 등록할 모듈 인스턴스
  /// - Returns: 메서드 체이닝을 가능하게 하기 위해 자기 자신(self)을 반환합니다.
  @discardableResult
  public func register(_ module: Module) -> Self {
    modules.append(module)
    return self
  }
  
  /// trailing closure를 처리하는 메서드입니다.
  ///
  /// - Parameter block: 실행할 클로저
  /// - Returns: 메서드 체이닝을 위해 자기 자신(self)을 반환합니다.
  @discardableResult
  public func callAsFunction(_ block: () -> Void) -> Self {
    block()  // 전달받은 클로저를 실행합니다.
    return self
  }
  
  /// 등록된 모든 모듈의 `register()` 메서드를 비동기 TaskGroup을 사용해 병렬로 실행합니다.
  ///
  /// 이 메서드는 각 모듈의 등록 과정을 동시에 실행하여 전체 빌드 시간을 단축시키는 효과가 있습니다.
  public func build() async {
    await withTaskGroup(of: Void.self) { group in
      // 배열에 있는 각 모듈에 대해 비동기 태스크를 추가합니다.
      for module in modules {
        group.addTask {
          await module.register()
        }
      }
      // withTaskGroup 클로저는 모든 태스크가 종료될 때까지 대기합니다.
    }
  }
}

#else
public final actor  Container {
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
    block()  // 전달받은 클로저를 실행합니다.
    return self
  }
  
  // 모든 모듈 등록 실행 (비동기)
  public func build() async {
    await withTaskGroup(of: Void.self) { group in
      // 배열에 있는 각 모듈에 대해 비동기 태스크를 추가합니다.
      for module in modules {
        group.addTask {
          await module.register()
        }
      }
      // withTaskGroup 클로저는 모든 태스크가 종료될 때까지 대기합니다.
    }
  }
}
#endif
