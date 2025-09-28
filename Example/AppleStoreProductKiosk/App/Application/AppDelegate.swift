//
//  AppDelegate.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/17/25.
//

import Foundation
import UIKit

import WeaveDI

class AppDelegate: UIResponder, UIApplicationDelegate {



  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    WeaveDI.Container.bootstrapInTask { _ in
      await AppDIContainer.shared.registerDefaultDependencies()
    }

    return true
  }
}
