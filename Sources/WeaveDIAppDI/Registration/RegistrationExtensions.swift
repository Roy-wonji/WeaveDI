//
//  RegistrationExtensions.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro
import WeaveDICore

// MARK: - Bulk Registration Extensions

extension RegisterModule {
  
  /// 인터페이스 패턴을 한번에 등록하는 시스템
  func registerInterfacePattern<Interface>(
    _ interfaceType: Interface.Type,
    repositoryFactory: @Sendable @escaping () -> Interface,
    useCaseFactory: @Sendable @escaping (Interface) -> Interface,
    repositoryFallback: @Sendable @escaping () -> Interface
  ) -> [() -> Module] where Interface: Sendable {
    
    let repositoryModule = makeDependency(interfaceType, factory: repositoryFactory)
    
    let useCaseModule = makeUseCaseWithRepository(
      interfaceType,
      repositoryProtocol: interfaceType,
      repositoryFallback: repositoryFallback(),
      factory: useCaseFactory
    )
    
    return [repositoryModule, useCaseModule]
  }
  
  /// 여러 인터페이스를 한번에 등록하는 시스템
  func bulkInterfaces(@BulkRegistrationBuilder _ builder: () -> [BulkRegistrationEntry]) -> [() -> Module] {
    let entries = builder()
    var allModules: [() -> Module] = []
    
    for entry in entries {
      let modules = entry.createModules(using: self)
      allModules.append(contentsOf: modules)
    }
    
    return allModules
  }
  
  /// 타입 안전한 간편 스코프 등록
  func easyScopes(@EasyScopeBuilder _ builder: () -> [RegisterEasyScopeEntry]) -> [() -> Module] {
    let entries = builder()
    return entries.map { entry in
      return { entry.createModule() }
    }
  }
}

// MARK: - Bulk Registration DSL

/// 벌크 등록을 위한 빌더
@resultBuilder
struct BulkRegistrationBuilder {
  public static func buildBlock(_ components: BulkRegistrationEntry...) -> [BulkRegistrationEntry] {
    Array(components)
  }
}

/// 벌크 등록 엔트리
struct BulkRegistrationEntry {
  private let createModulesFunc: (RegisterModule) -> [() -> Module]
  
  public init<Interface>(
    interfaceType: Interface.Type,
    repository: @Sendable @escaping () -> Interface,
    useCase: @Sendable @escaping (Interface) -> Interface,
    fallback: @Sendable @escaping () -> Interface
  ) where Interface: Sendable {
    self.createModulesFunc = { registerModule in
      registerModule.interface(
        interfaceType,
        repository: repository,
        useCase: useCase,
        fallback: fallback
      )
    }
  }
  
  func createModules(using registerModule: RegisterModule) -> [() -> Module] {
    return createModulesFunc(registerModule)
  }
}

// MARK: - Easy Scope DSL

/// 간편한 스코프 등록을 위한 빌더
@resultBuilder
struct EasyScopeBuilder {
  public static func buildBlock(_ components: RegisterEasyScopeEntry...) -> [RegisterEasyScopeEntry] {
    Array(components)
  }
  
  public static func buildArray(_ components: [[RegisterEasyScopeEntry]]) -> [RegisterEasyScopeEntry] {
    components.flatMap { $0 }
  }
  
  public static func buildOptional(_ component: [RegisterEasyScopeEntry]?) -> [RegisterEasyScopeEntry] {
    component ?? []
  }
}

/// 간편한 스코프 엔트리
struct RegisterEasyScopeEntry {
  private let moduleFactory: () -> Module
  
  public init<T>(type: T.Type, factory: @Sendable @escaping () -> T) where T: Sendable {
    self.moduleFactory = { Module(type, factory: factory) }
  }
  
  func createModule() -> Module {
    moduleFactory()
  }
}

// MARK: - DSL Operators

infix operator => : AssignmentPrecedence

/// 벌크 등록을 위한 연산자
func =><Interface>(
  lhs: Interface.Type,
  rhs: (
    repository: @Sendable () -> Interface,
    useCase: @Sendable (Interface) -> Interface,
    fallback: @Sendable () -> Interface
  )
) -> BulkRegistrationEntry where Interface: Sendable {
  BulkRegistrationEntry(
    interfaceType: lhs,
    repository: rhs.repository,
    useCase: rhs.useCase,
    fallback: rhs.fallback
  )
}

// MARK: - Global Convenience Functions

/// 전역 함수로 더욱 간편한 등록
func register<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) -> RegisterEasyScopeEntry where T: Sendable {
  RegisterEasyScopeEntry(type: type, factory: factory)
}

/// 사용자를 위한 전역 인터페이스 등록 함수
func registerInterface<Interface>(
  _ interfaceType: Interface.Type,
  repository: @Sendable @escaping () -> Interface,
  useCase: @Sendable @escaping (Interface) -> Interface,
  fallback: @Sendable @escaping () -> Interface
) -> [() -> Module] where Interface: Sendable {
  let registerModule = RegisterModule()
  return registerModule.interface(
    interfaceType,
    repository: repository,
    useCase: useCase,
    fallback: fallback
  )
}
