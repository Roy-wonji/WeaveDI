//
//  Extension+RepositoryModuleFactory.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/17/25.
//

import Foundation

import DiContainer

extension RepositoryModuleFactory {
  public mutating func registerDefaultDefinitions() {
    let register = registerModule

    definitions = {
      return [
        register.productRepositoryImplModule
      ]
    }()
  }
}
