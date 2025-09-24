//
//  CartFeature.swift
//  AppleStoreProductKiosk
//
//  Created by 김민희 on 9/18/25.
//
import Foundation
import ComposableArchitecture

@Reducer
public struct CartFeature {
  @ObservableState
  public struct State: Equatable {
    @Shared var selectedProducts: [Product]
    @Presents var alert: AlertState<Action.Alert>?
  }
  
  @CasePathable
  public enum Action: Equatable {
    case decreaseQuantity(Product.ID)
    case increaseQuantity(Product)
    case removeProduct(Product.ID)
    case clearCart
    case checkoutButtonTapped
    case alert(PresentationAction<Alert>)
    
    @CasePathable
    public enum Alert: Equatable {
      case dismiss
    }
  }
  
  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .decreaseQuantity(let id):
        state.$selectedProducts.withLock { products in
          guard let index = products.firstIndex(where: { $0.id == id }) else { return }
          products.remove(at: index)
        }
        return .none
        
      case .increaseQuantity(let product):
        state.$selectedProducts.withLock { $0.append(product) }
        return .none
        
      case .removeProduct(let id):
        state.$selectedProducts.withLock { products in
          products.removeAll { $0.id == id }
        }
        return .none
        
      case .clearCart:
        state.$selectedProducts.withLock { $0.removeAll() }
        return .none
        
      case .checkoutButtonTapped:
        guard !state.selectedProducts.isEmpty else {
          state.alert = AlertState {
            TextState("장바구니 비어 있음")
          } actions: {
            ButtonState(action: .dismiss) {
              TextState("확인")
            }
          } message: {
            TextState("상품을 선택해주세요")
          }
          return .none
        }
        
        let totalPrice = state.selectedProducts.reduce(0) { $0 + $1.price }
        let formattedTotal = totalPrice.formatted(.currency(code: "KRW"))
        state.alert = AlertState {
          TextState("결제 완료")
        } actions: {
          ButtonState(action: .dismiss) {
            TextState("확인")
          }
        } message: {
          TextState("총 \(formattedTotal)의 주문이 접수되었습니다.\n감사합니다!")
        }
        state.$selectedProducts.withLock { $0.removeAll() }
        return .none
        
      case .alert(.dismiss):
        return .none
      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
