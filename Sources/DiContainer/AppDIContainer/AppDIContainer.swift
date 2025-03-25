//
//  AppDIContainer.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

/// AppDIContainer는 애플리케이션의 의존성 주입(Dependency Injection)을 담당하는 중앙 컨테이너입니다.
/// 이 클래스는 싱글턴 패턴을 사용하여 전역에서 동일한 인스턴스를 참조할 수 있도록 설계되었습니다.
#if swift(>=5.9)
@available(iOS 17.0, *)

public final actor AppDIContainer {
  @Factory(\.repositoryFactory) public var repositoryFactory: RepositoryModuleFactory
  @Factory(\.useCaseFactory) public var useCaseFactory: UseCaseModuleFactory

  public static let shared: AppDIContainer = .init()
  
  private init() {}

  private let container = Container()
  
  /// registerDependencies 메서드는 비동기 클로저를 받아, 해당 클로저에서 의존성 모듈들을 등록하도록 합니다.
  /// 이후 container.build()를 호출하여, 등록된 모든 모듈의 register() 메서드를 비동기적으로 실행합니다.
  ///
  /// - Parameter registerModules: Container를 인자로 받아 비동기적으로 의존성 모듈들을 등록하는 클로저.
  /// - Note: 이 클로저는 앱(또는 라이브러리 사용자)이 원하는 의존성 등록 로직을 제공할 수 있도록 합니다.
  public func registerDependencies(
    registerModules: @escaping (Container) async -> Void
  ) async {
    // 로컬 상수에 container를 복사하여 self를 캡처하지 않도록 합니다.
    let containerCopy = container
    
    // 1. 전달받은 비동기 클로저를 로컬 containerCopy를 사용하여 실행합니다.
    await registerModules(containerCopy)
    
    // 2. containerCopy에 등록된 모든 모듈의 register()를 비동기적으로 실행합니다.
    await containerCopy {
      // 이 클로저는 비어있지만, callAsFunction 메서드를 통해 메서드 체이닝이 가능합니다.
    }.build()
  }
}

#else
public final actor  AppDIContainer {
  /// 전역 싱글턴 인스턴스입니다.
  @Factory(\.repositoryFactory) public var repositoryFactory: RepositoryModuleFactory
  @Factory(\.useCaseFactory) public var useCaseFactory: UseCaseModuleFactory

  /// 외부에서 생성하지 못하도록 private으로 생성자를 감춥니다.
  ///
  public static let shared: AppDIContainer = .init()
  
  private init() {}
  
  /// 내부에 DI 모듈을 관리하는 Container 인스턴스를 보관합니다.
  /// Container는 개별 모듈들을 등록(register)하고, build()를 통해 모든 등록된 모듈의 의존성 등록을 수행합니다.
  private let container = Container()
  
  /// registerDependencies 메서드는 비동기 클로저를 받아, 해당 클로저에서 의존성 모듈들을 등록하도록 합니다.
  /// 이후 container.build()를 호출하여, 등록된 모든 모듈의 register() 메서드를 비동기적으로 실행합니다.
  ///
  /// - Parameter registerModules: Container를 인자로 받아 비동기적으로 의존성 모듈들을 등록하는 클로저.
  /// - Note: 이 클로저는 앱(또는 라이브러리 사용자)이 원하는 의존성 등록 로직을 제공할 수 있도록 합니다.
  public func registerDependencies(
    registerModules: @escaping (Container) async -> Void
  ) async {
    // 1. 전달받은 비동기 클로저(registerModules)를 실행합니다.
    //    이 클로저 내부에서 필요한 의존성 모듈들이 container에 등록됩니다.
    let containerCopy = container
    
    await registerModules(containerCopy)
    
    // 2. container에 등록된 모든 모듈의 register() 메서드를 실행합니다.
    //    여기서 callAsFunction은 빈 클로저를 사용하여, 단순히 container의 build()를 호출할 수 있도록 합니다.
    await containerCopy {
      // 이 클로저는 비어있지만, callAsFunction 메서드를 활용해 메서드 체이닝을 가능하게 합니다.
    }.build()
  }
}
#endif
