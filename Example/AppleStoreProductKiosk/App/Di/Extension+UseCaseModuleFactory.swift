//
//  Extension+UseCaseModuleFactory.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/17/25.
//

import Foundation

import WeaveDI

extension UseCaseModuleFactory {
  public mutating func registerDefaultDefinitions() {
    let register = registerModule

    self.definitions = {
      return [
          register.productUseCaseImplModule,
      ]
    }()
  }
}
