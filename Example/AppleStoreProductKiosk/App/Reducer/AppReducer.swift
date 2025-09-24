//
//  AppReducer.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/17/25.
//

import Foundation

import ComposableArchitecture

@Reducer
struct AppReducer {

  @ObservableState
  enum State: Equatable {
    case productList(ProductListFeature.State)

    init() {
      let selectedProducts = Shared<[Product]>(value: [])
      self = .productList(.init(selectedProducts: selectedProducts))
    }
  }

  enum Action: ViewAction {
    case view(View)
  }

  @CasePathable
  enum View {
    case productList(ProductListFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
        case .view(let ViewAction):
          handleViewAction(&state, action: ViewAction)
      }
    }
    .ifCaseLet(\.productList, action: \.view.productList) {
      ProductListFeature()
    }
  }

  func handleViewAction(
    _ state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
      case .productList:
        return .none
    }
  }
}
