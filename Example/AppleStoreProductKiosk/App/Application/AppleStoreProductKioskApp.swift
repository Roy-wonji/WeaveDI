//
//  AppleStoreProductKioskApp.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/16/25.
//

import SwiftUI
import ComposableArchitecture

@main
struct AppleStoreProductKioskApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
          let store = Store(initialState: AppReducer.State()) {
            AppReducer()
              ._printChanges()
              ._printChanges(.actionLabels)
          }

          AppView(store: store)
        }
    }
}
