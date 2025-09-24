//
//  CartView.swift
//  AppleStoreProductKiosk
//
//  Created by 김민희 on 9/16/25.
//

import SwiftUI
import ComposableArchitecture

struct CartView: View {
  @Perception.Bindable var store: StoreOf<CartFeature>

  public init(store: StoreOf<CartFeature>) {
    self.store = store
  }

  var body: some View {
    WithPerceptionTracking {
      let items = makeCartItems(from: store.selectedProducts)

      VStack(spacing: 0) {
        CartHeaderView()

        Divider()

        if items.isEmpty {
          emptyStateView
        } else {
          ScrollView {
            VStack(spacing: 15) {
              ForEach(items) { item in
                CartItemRowView(
                  item: item,
                  onTapDecrease: { store.send(.decreaseQuantity(item.product.id)) },
                  onTapIncrease: { store.send(.increaseQuantity(item.product)) },
                  onTapRemove: { store.send(.removeProduct(item.product.id)) }
                )
              }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 30)
          }
          .scrollIndicators(.hidden)
        }

        Divider()

        CartSummaryView(
          totalQuantity: items.reduce(0) { $0 + $1.quantity },
          totalPrice: items.reduce(0) { $0 + $1.subtotal }
        )
        .padding(.vertical, 20)

        CartActionButtonsView(
          onTapCancel: { store.send(.clearCart) },
          onTapCheckout: { store.send(.checkoutButtonTapped) }
        )
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }

  private var emptyStateView: some View {
    VStack(spacing: 12) {
      Image(systemName: "cart")
        .font(.system(size: 36, weight: .regular))
        .foregroundStyle(.gray.opacity(0.6))
      Text("장바구니가 비어 있어요.")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.gray)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.vertical, 60)
  }

  private func makeCartItems(from products: [Product]) -> [CartItem] {
    Dictionary(grouping: products, by: \.id)
      .compactMap { _, items in
        guard let product = items.first else { return nil }
        return CartItem(product: product, quantity: items.count)
      }
      .sorted { $0.product.name < $1.product.name }
  }
}

//#Preview {
//  CartView()
//}
