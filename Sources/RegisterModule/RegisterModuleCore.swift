//
//  RegisterModuleCore.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

/// RegisterModule의 핵심 기능만 포함한 깔끔한 버전
public struct RegisterModule: Sendable {
    
    // MARK: - 초기화
    
    /// 기본 생성자
    public init() {}
    
    // MARK: - 기본 모듈 생성
    
    /// 타입과 팩토리 클로저로부터 Module 인스턴스를 생성하는 기본 메서드입니다.
    public func makeModule<T>(
        _ type: T.Type,
        factory: @Sendable @escaping () -> T
    ) -> Module {
        Module(type, factory: factory)
    }
    
    /// 특정 프로토콜 타입에 대해 Module을 생성하는 클로저를 반환합니다.
    public func makeDependency<T>(
        _ protocolType: T.Type,
        factory: @Sendable @escaping () -> T
    ) -> @Sendable () -> Module {
        return {
            Module(protocolType, factory: factory)
        }
    }
    
    
    // MARK: - UseCase with Repository 패턴
    
    /// UseCase 모듈 생성 시, DI 컨테이너에서 Repository 인스턴스를 자동으로 주입합니다.
    public func makeUseCaseWithRepository<UseCase, Repo>(
        _ useCaseProtocol: UseCase.Type,
        repositoryProtocol: Repo.Type,
        repositoryFallback: @Sendable @autoclosure @escaping () -> Repo,
        factory: @Sendable @escaping (Repo) -> UseCase
    ) -> @Sendable () -> Module {
        
        return {
            // Repository 조회
            let repository: Repo = self.resolveOrDefault(
                for: repositoryProtocol,
                fallback: repositoryFallback()
            )
            
            return Module(useCaseProtocol, factory: {
                factory(repository)
            })
        }
    }
    
    // MARK: - 의존성 조회 헬퍼
    
    /// 의존성을 조회하고, 없을 경우 기본값을 반환합니다.
    public func resolveOrDefault<T>(
        for type: T.Type,
        fallback: @Sendable @autoclosure @escaping () -> T
    ) -> T {
        if let resolved: T = DependencyContainer.live.resolve(type) {
            return resolved
        }
        return fallback()
    }


  /// 사용자의 기존 패턴과 완전히 동일한 한번에 등록
  ///
  /// ## 사용법 (사용자의 기존 코드와 1:1 대응):
  /// ```swift
  /// // 기존 코드를 이렇게 변환:
  /// let modules = registerModule.interface(
  ///     AuthInterface.self,
  ///     repository: { AuthRepositoryImpl() },
  ///     useCase: { repo in AuthUseCaseImpl(repository: repo) },
  ///     fallback: { DefaultAuthRepositoryImpl() }
  /// )
  ///
  /// // 등록
  /// for moduleFactory in modules {
  ///     await container.register(moduleFactory())
  /// }
  /// ```
  public func interface<Interface>(
      _ interfaceType: Interface.Type,
      repository repositoryFactory: @Sendable @escaping () -> Interface,
      useCase useCaseFactory: @Sendable @escaping (Interface) -> Interface,
      fallback fallbackFactory: @Sendable @escaping () -> Interface
  ) -> [() -> Module] {

      return [
          // Repository 모듈 (기존 authRepositoryImplModule과 동일)
          makeDependency(interfaceType, factory: repositoryFactory),

          // UseCase 모듈 (기존 authUseCaseImplModule과 동일)
          makeUseCaseWithRepository(
              interfaceType,
              repositoryProtocol: interfaceType,
              repositoryFallback: fallbackFactory(),
              factory: useCaseFactory
          )
      ]
  }

    /// 기본 인스턴스를 제공합니다.
    public func defaultInstance<T>(
        for type: T.Type,
        fallback: @Sendable @autoclosure @escaping () -> T
    ) -> T {
        return resolveOrDefault(for: type, fallback: fallback())
    }
}
