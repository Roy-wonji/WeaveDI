//
//  DIContainer+Factories.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//

import Foundation
import WeaveDICore

// MARK: - Factory KeyPath Extensions

/// Factory 타입들을 위한 KeyPath 확장
public extension DIContainer {

  /// Repository 모듈 팩토리 KeyPath
  var repositoryFactory: RepositoryModuleFactory? {
    resolve(RepositoryModuleFactory.self)
  }

  /// UseCase 모듈 팩토리 KeyPath
  var useCaseFactory: UseCaseModuleFactory? {
    resolve(UseCaseModuleFactory.self)
  }

  /// Scope 모듈 팩토리 KeyPath
  var scopeFactory: ScopeModuleFactory? {
    resolve(ScopeModuleFactory.self)
  }

  /// 모듈 팩토리 매니저 KeyPath
  var moduleFactoryManager: ModuleFactoryManager? {
    resolve(ModuleFactoryManager.self)
  }
}
