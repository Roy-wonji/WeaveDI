//
//  Extension+UseCaseModuleFactory.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/17/25.
//

import Foundation

import DiContainer

extension UseCaseModuleFactory {
  public mutating func registerDefaultDefinitions() {
    let register = registerModule

    definitions = {
      return [
        register.productUseCaseImplModule,
      ]
    }()
  }
}
