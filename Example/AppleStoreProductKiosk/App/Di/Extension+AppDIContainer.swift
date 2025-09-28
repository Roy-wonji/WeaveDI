//
//  Extension+AppDIContainer.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/17/25.
//

import Foundation
import WeaveDI

extension AppDIContainer {
  func registerDefaultDependencies() async {
    await registerDependencies { container in
      // Repository 먼저 등록
      let factory = ModuleFactoryManager()

      await factory.registerAll(to: container)

    }
  }
}

