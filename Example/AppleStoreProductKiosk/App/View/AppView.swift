//
//  AppView.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/17/25.
//

import SwiftUI

import ComposableArchitecture

struct AppView: View {
  @Perception.Bindable var store: StoreOf<AppReducer>

  var body: some View {
    switch store.state {
    case .productList:
        if let store = store.scope(state: \.productList, action: \.view.productList) {
        ProductListView(store: store)
      }
    }
  }
}
