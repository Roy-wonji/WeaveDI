//
//  CartButtonFeature.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/17/25.
//

import Foundation
import ComposableArchitecture

@Reducer
public struct CartButtonFeature {
  
  @ObservableState
  public struct State: Equatable {
    @Shared var selectedProducts: [Product]
    var totalPrice: Double {
      return selectedProducts.map { $0.price }.reduce(0, +)
    }
  }
  
  public enum Action: ViewAction, Equatable {
    case view(ViewAction)
    
    public enum ViewAction: Equatable {
      case onTap
    }
  }
  
  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .view:
        return .none
      }
    }
  }
}
