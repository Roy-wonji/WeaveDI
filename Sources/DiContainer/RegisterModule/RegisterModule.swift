//
//  RegisterModule.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/19/25.
//

import Foundation

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
