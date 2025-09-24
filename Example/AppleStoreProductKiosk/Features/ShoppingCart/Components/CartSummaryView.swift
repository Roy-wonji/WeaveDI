//
//  CartSummaryView.swift
//  AppleStoreProductKiosk
//
//  Created by 김민희 on 9/17/25.
//

import SwiftUI

struct CartSummaryView: View {
  let totalQuantity: Int
  let totalPrice: Double

  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        Text("상품 개수")
          .font(.system(size: 14, weight: .regular))
          .foregroundStyle(.black.opacity(0.7))
        Text("총 결제금액")
          .font(.system(size: 18, weight: .semibold))
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 10) {
        Text("\(totalQuantity)개")
          .font(.system(size: 14, weight: .semibold))
        Text(totalPrice.formatted(.currency(code: "KRW")))
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(.blue)
      }

    }
    .padding(.horizontal, 20)
  }
}

#Preview {
  CartSummaryView(totalQuantity: 3, totalPrice: 3890000)
    .padding(.horizontal, 20)
}
