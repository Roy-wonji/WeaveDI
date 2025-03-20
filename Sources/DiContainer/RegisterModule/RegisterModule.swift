//
//  RegisterModule.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation

#if swift(>=5.9)
@available(iOS 17.0, *)
/// RegisterModule은 Repository와 UseCase 모듈을 생성하고 의존성을 주입하는 공통 로직을 제공합니다.
/// 이 구조체를 통해 모듈을 생성하는 팩토리 메서드들을 호출하여, DI 컨테이너에 의존성을 등록하거나
/// 필요한 경우 기본 인스턴스를 반환받을 수 있습니다.
public struct RegisterModule: Sendable {
  
  /// 기본 생성자입니다.
  public init() {}
  
  /// 주어진 타입의 팩토리 클로저를 사용해 Module 인스턴스를 생성합니다.
  ///
  /// - Parameters:
  ///   - type: 생성할 의존성의 타입 (예: AuthRepositoryProtocol.self)
  ///   - factory: 의존성 인스턴스를 생성하는 클로저
  /// - Returns: 생성된 Module 인스턴스
  public func makeModule<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () -> T
  ) -> Module {
    Module(type, factory: factory)
  }
  
  // MARK: - Repository/UseCase 공통 모듈 생성
  
  /// Repository나 UseCase 모듈을 생성하기 위한 내부 헬퍼 메서드입니다.
  /// 실제로는 makeModule(_:factory:)를 호출하여 Module을 생성합니다.
  ///
  /// - Parameters:
  ///   - type: 생성할 의존성의 타입
  ///   - factory: 의존성 인스턴스를 생성하는 클로저
  /// - Returns: 생성된 Module 인스턴스
  private func makeDependencyModule<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () -> T
  ) -> Module {
    self.makeModule(type, factory: factory)
  }
  
  // MARK: - 통합 의존성 생성 함수: Repository와 UseCase 모두 동일한 로직을 사용합니다.
  
  /// 통합 의존성 생성 함수로, 특정 프로토콜 타입에 대해 Module을 생성하는 클로저를 반환합니다.
  ///
  /// - Parameters:
  ///   - protocolType: 등록할 의존성의 프로토콜 타입
  ///   - factory: 의존성 인스턴스를 생성하는 클로저 (T 타입으로 캐스팅 가능한 U 타입을 반환)
  /// - Returns: Module을 생성하는 클로저. 이 클로저를 호출하면 DI 컨테이너에 등록할 Module이 생성됩니다.
  public func makeDependency<T, U>(
    _ protocolType: T.Type,
    factory: @Sendable @escaping () -> U
  ) -> () -> Module {
    return {
      // makeDependencyModule 내부에서 factory()를 호출한 결과를 T 타입으로 캐스팅합니다.
      // 만약 캐스팅에 실패하면 fatalError가 발생합니다.
      self.makeDependencyModule(protocolType) {
        guard let dependency = factory() as? T else {
          fatalError("Failed to cast \(U.self) to \(T.self)")
        }
        return dependency
      }
    }
  }
  
  // MARK: - Repository 의존성을 자동으로 주입받아 UseCase 모듈을 생성하는 함수.
  /// 이 메서드는 UseCase 모듈을 생성할 때 Repository 의존성을 자동으로 주입받아 UseCase 인스턴스를 생성합니다.
  ///
  /// - Parameters:
  ///   - useCaseProtocol: 등록할 UseCase 프로토콜 타입
  ///   - repositoryProtocol: 주입할 Repository 프로토콜 타입
  ///   - repositoryFallback: Repository가 등록되어 있지 않을 경우 반환할 기본 인스턴스를 생성하는 fallback
  ///   - factory: 주입된 Repository를 사용하여 UseCase 인스턴스를 생성하는 클로저
  /// - Returns: Module을 생성하는 클로저. 이 클로저를 호출하면 자동으로 Repository가 주입된 UseCase 모듈이 생성됩니다.
  public func makeUseCaseWithRepository<UseCase, Repo>(
    _ useCaseProtocol: UseCase.Type,
    repositoryProtocol: Repo.Type,
    repositoryFallback: @Sendable @autoclosure @escaping () -> Repo,
    factory: @Sendable @escaping (Repo) -> UseCase
  ) -> () -> Module {
    return makeDependency(useCaseProtocol) {
      // DI 컨테이너에 등록된 Repository 인스턴스를 조회하거나, 없으면 fallback 인스턴스를 반환받습니다.
      let repo: Repo = self.defaultInstance(for: repositoryProtocol, fallback: repositoryFallback())
      // 조회된 Repository 인스턴스를 사용해 UseCase 인스턴스를 생성합니다.
      return factory(repo)
    }
  }
  
  // MARK: - DI에 등록
  
  /// 주어진 타입의 의존성을 DI 컨테이너에서 조회하거나 기본값을 반환합니다.
  ///
  /// - Parameters:
  ///   - type: 조회할 의존성의 타입
  ///   - defaultFactory: 의존성이 없을 경우 사용할 기본값을 생성하는 클로저 (@autoclosure 사용)
  /// - Returns: 조회된 의존성 또는 기본값
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultFactory: @autoclosure @escaping () -> T
  ) -> T {
    DependencyContainer.live.resolveOrDefault(type, default: defaultFactory())
  }
  
  // MARK: - 주어진 타입에 대해 기본 인스턴스를 반환하는
  /// DI 컨테이너에 등록된 인스턴스가 있으면 해당 인스턴스를, 없으면 fallback 인스턴스를 반환합니다.
  ///
  /// - Parameters:
  ///   - type: 조회할 의존성의 타입
  ///   - fallback: 의존성이 등록되어 있지 않을 경우 사용할 기본 인스턴스를 생성하는 클로저
  /// - Returns: 해당 타입의 의존성 인스턴스
  public func defaultInstance<T>(
    for type: T.Type,
    fallback: @Sendable @autoclosure @escaping () -> T
  ) -> T {
    return resolveOrDefault(type, default: fallback())
  }
}

#else
public struct RegisterModule {
  public init() {}

  public func makeModule<T>(_ type: T.Type, factory: @escaping () -> T) -> Module {
    Module(type, factory: factory)
  }
  
  // MARK: - Repository/UseCase 공통 모듈 생성
  private func makeDependencyModule<T>(
    _ type: T.Type,
    factory: @escaping () -> T
  ) -> Module {
    self.makeModule(type, factory: factory)
  }
  
  // MARK: -  통합 의존성 생성 함수: Repository와 UseCase 모두 동일한 로직을 사용합니다.
  public func makeDependency<T, U>(
    _ protocolType: T.Type,
    factory: @escaping () -> U
  ) -> () -> Module {
    return {
      self.makeDependencyModule(protocolType) {
        guard let dependency = factory() as? T else {
          fatalError("Failed to cast \(U.self) to \(T.self)")
        }
        return dependency
      }
    }
  }
  
  //MARK: - Repository 의존성을 자동으로 주입받아 UseCase 모듈을 생성하는 함수.
   /// - Parameters:
   ///   - useCaseProtocol: 등록할 UseCase 프로토콜 타입
   ///   - repositoryProtocol: 주입할 Repository 프로토콜 타입
   ///   - repositoryFallback: Repository의 기본 인스턴스를 반환하는 fallback
   ///   - factory: 주입된 Repository를 사용하여 UseCase 인스턴스를 생성하는 클로저
   /// - Returns: Module을 생성하는 클로저
  public func makeUseCaseWithRepository<UseCase, Repo>(
      _ useCaseProtocol: UseCase.Type,
      repositoryProtocol: Repo.Type,
      repositoryFallback: @autoclosure @escaping () -> Repo,
      factory: @escaping (Repo) -> UseCase
    ) -> () -> Module {
      return makeDependency(useCaseProtocol) {
        let repo: Repo = self.defaultInstance(for: repositoryProtocol, fallback: repositoryFallback())
        return factory(repo)
      }
    }
  
  // MARK: - di에 등록
  public func resolveOrDefault<T>(
    _ type: T.Type,
    default defaultFactory: @autoclosure @escaping () -> T
  ) -> T {
    DependencyContainer.live.resolveOrDefault(type, default: defaultFactory())
  }
  
  //MARK: - 주어진 타입에 대해 기본 인스턴스를 반환하는
  /// DI 컨테이너에 등록된 인스턴스가 있으면 해당 인스턴스를, 없으면 fallback 인스턴스를 반환합니다.
  public func defaultInstance<T>(
    for type: T.Type,
    fallback: @autoclosure @escaping () -> T
  ) -> T {
    return resolveOrDefault(type, default: fallback())
  }
}
#endif
