//
//  ProductListView.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/17/25.
//

import SwiftUI
import ComposableArchitecture
import WeaveDI

@ViewAction(for: ProductListFeature.self)
public struct ProductListView: View {
  @Perception.Bindable public var store: StoreOf<ProductListFeature>
  @Environment(\.horizontalSizeClass) var horizontalSizeClass
  @Environment(\.verticalSizeClass) var verticalSizeClass
  
  private var adaptiveColumnCount: Int {
    switch (horizontalSizeClass, verticalSizeClass) {
    case (.compact, .regular):     // iPhone 세로
      return 2
    case (.compact, .compact):     // iPhone 가로
      return 3
    case (.regular, .regular):     // iPad 세로
      return 4
    case (.regular, .compact):     // iPad 가로
      return 5
    default:
      return 2
    }
  }
  
  private var columns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 16), count: adaptiveColumnCount)
  }
  
  public var body: some View {
    WithPerceptionTracking {
      VStack {
        headerView
        
        SegmentsView(
          items: store.productCategories.map {
            SegmentData(id: $0.id, title: $0.name, icon: $0.name)
          },
          selectedID: $store.currentSelectedCategoryId
        )
        
        ScrollView {
          productGrid
          Spacer()
        }
        .scrollIndicators(.hidden)
      }
      .safeAreaInset(edge: .bottom) {
        if !store.isHiddenCartButton {
          CartButtonView(
            store: store.scope(
              state: \.cartButtonState,
              action: \.scope.cardButton
            )
          )
          .shadow(radius: 8, x: 4, y: 4)
          .padding()
        }
      }
      .onAppear {
        send(.onAppear)
      }
      .alert($store.scope(state: \.alert, action: \.view.alert))
      .cartSheet(store: store)
    }
  }
}

private extension ProductListView {
  var headerView: some View {
    VStack {
      Text("Apple Store")
        .font(.largeTitle)
        .fontWeight(.bold)
      Text("원하는 제품을 선택하고 주문하세요.")
        .font(.subheadline)
        .foregroundStyle(Color.secondary)
    }
  }
  
  var productGrid: some View {
    LazyVGrid(columns: columns, spacing: 16) {
      ForEach(store.currentItems) { product in
        ProductCardView(product: product) { id in
          send(.onTapAddItem(id: id))
        }
      }
    }
    .padding(8)
  }
}

private extension View {
  func cartSheet(store: StoreOf<ProductListFeature>) -> some View {
    self.sheet(
      store: store.scope(state: \.$cart, action: \.scope.cart)  
    ) { cartStore in
      CartView(store: cartStore)
    }
  }
}

#Preview {
  let initialSelected = Shared<[Product]>(value: [])
  ProductListView(
    store: Store(
      initialState: ProductListFeature.State(selectedProducts: initialSelected)
    ) {
      ProductListFeature()
    }
  )
}
