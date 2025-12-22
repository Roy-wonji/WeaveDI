//
//  RegistrationCore.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/19/25.
//

import Foundation
import LogMacro
import WeaveDICore

// MARK: - Module

/// `Module`은 DI(의존성 주입)를 위한 **단일 모듈**을 나타내는 구조체입니다.
///
/// 이 타입을 사용하면, 특정 타입의 인스턴스를 `DIContainer`에
/// **비동기적으로 등록**하는 작업을 하나의 객체로 캡슐화할 수 있습니다.
public struct Module: Sendable {
  private let registrationClosure: @Sendable () async -> Void
  // Debug metadata for diagnostics and reporting
  internal let debugTypeName: String
  internal let debugFile: String
  internal let debugFunction: String
  internal let debugLine: Int
  
  public init<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () -> T,
    file: StaticString = #fileID,
    function: StaticString = #function,
    line: UInt = #line
  ) where T: Sendable {
    self.registrationClosure = {
      DIContainer.shared.register(type, build: factory)
    }
    self.debugTypeName = String(describing: T.self)
    self.debugFile = String(describing: file)
    self.debugFunction = String(describing: function)
    self.debugLine = Int(line)
    
    // Graph: record node
    if let addNode = OptimizationHooks.addGraphNode {
      Task.detached { @Sendable in
        await addNode(T.self)
      }
    }
  }
  
  public func register() async { await registrationClosure() }
  
  /// Throwing variant kept for future expandability
  public func registerThrowing() async throws { await registrationClosure() }
}

// MARK: - RegisterModule

/// RegisterModule의 핵심 기능만 포함한 깔끔한 버전
public struct RegisterModule: Sendable {
  
  public init() {}
  
  // MARK: - 기본 모듈 생성
  
  public func makeModule<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () -> T
  ) -> Module where T: Sendable {
    Module(type, factory: factory)
  }
  
  public func makeDependency<T>(
    _ protocolType: T.Type,
    factory: @Sendable @escaping () -> T
  ) -> @Sendable () -> Module where T: Sendable {
    return {
      Module(protocolType, factory: factory)
    }
  }
  
  // MARK: - UseCase with Repository 패턴
  
  public func makeUseCaseWithRepository<UseCase, Repo>(
    _ useCaseProtocol: UseCase.Type,
    repositoryProtocol: Repo.Type,
    repositoryFallback: @Sendable @autoclosure @escaping () -> Repo,
    factory: @Sendable @escaping (Repo) -> UseCase
  ) -> @Sendable () -> Module where UseCase: Sendable, Repo: Sendable {
    if let addEdge = OptimizationHooks.addGraphEdge {
      Task.detached { @Sendable in
        await addEdge(useCaseProtocol, repositoryProtocol, "uses")
      }
    }
    return { [repositoryProtocol] in
      Module(useCaseProtocol, factory: {
        if let repo: Repo = DIContainer.shared.resolve(repositoryProtocol) {
          return factory(repo)
        } else {
          return factory(repositoryFallback())
        }
      })
    }
  }
  
  // MARK: - 의존성 조회 헬퍼
  
  public func resolveOrDefault<T>(
    for type: T.Type,
    fallback: @Sendable @autoclosure @escaping () -> T
  ) -> T where T: Sendable {
    if let resolved: T = DIContainer.shared.resolve(type) {
      return resolved
    }
    return fallback()
  }
  
  public func interface<Interface>(
    _ interfaceType: Interface.Type,
    repository repositoryFactory: @Sendable @escaping () -> Interface,
    useCase useCaseFactory: @Sendable @escaping (Interface) -> Interface,
    fallback fallbackFactory: @Sendable @escaping () -> Interface
  ) -> [() -> Module] where Interface: Sendable {
    return [
      makeDependency(interfaceType, factory: repositoryFactory),
      makeUseCaseWithRepository(
        interfaceType,
        repositoryProtocol: interfaceType,
        repositoryFallback: fallbackFactory(),
        factory: useCaseFactory
      )
    ]
  }
  
  public func defaultInstance<T>(
    for type: T.Type,
    fallback: @Sendable @autoclosure @escaping () -> T
  ) -> T where T: Sendable {
    return resolveOrDefault(for: type, fallback: fallback())
  }
}

// MARK: - Sendable Helpers

/// A lightweight helper to intentionally box non-Sendable values
/// for use inside @Sendable closures. Use with caution and only if
/// you can guarantee thread-safety of the underlying value.
public struct UncheckedSendableBox<T>: @unchecked Sendable {
  public let value: T
  public init(_ value: T) { self.value = value }
}

/// Convenience function to create an UncheckedSendableBox
@inlinable
public func unsafeSendable<T>(_ value: T) -> UncheckedSendableBox<T> {
  UncheckedSendableBox(value)
}
