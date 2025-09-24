//
//  CartButtonView.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/17/25.
//

import SwiftUI
import ComposableArchitecture

@ViewAction(for: CartButtonFeature.self)
struct CartButtonView: View {
  let store: StoreOf<CartButtonFeature>
  
  var body: some View {
    Button {
      send(.onTap)
    } label: {
      HStack(spacing: 12) {
        ZStack(alignment: .topTrailing) {
          Image(systemName: "cart")
            .foregroundStyle(Color.white)
          
          if store.selectedProducts.count > 0 {
            Text("\(min(store.selectedProducts.count, 99))") // 99개 제한
              .font(.system(size: 8, weight: .bold))
              .padding(2)
              .foregroundColor(.blue)
              .background(Color.white)
              .clipShape(Circle())
              .offset(x: 5, y: -5)
          }
        }
        
        Text("장바구니 보기")
          .foregroundStyle(Color.white)
          .font(.system(size: 14, weight: .bold))
        
        Spacer()
        
        Text(store.totalPrice.formattedKRWCurruncy)
          .foregroundStyle(Color.white)
          .font(.system(size: 14, weight: .bold))
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(.vertical, 14)
      .padding(.horizontal, 16)
      .background(Color.accentColor)
      .clipShape(RoundedRectangle(cornerRadius: 16))
    }
  }
}

#Preview {
  let initialSelected = Shared<[Product]>(value: Product.allProducts)
  return CartButtonView(
    store: Store(
      initialState: CartButtonFeature.State(
        selectedProducts: initialSelected
      ),
      reducer: {
        CartButtonFeature()
      }
    )
  )
  .padding()
}
