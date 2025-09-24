//
//  CartActionButtonsView.swift
//  AppleStoreProductKiosk
//
//  Created by 김민희 on 9/17/25.
//

import SwiftUI

struct CartActionButtonsView: View {
  let onTapCancel: () -> Void
  let onTapCheckout: () -> Void
  
  var body: some View {
    Grid(horizontalSpacing: 12) {
      GridRow {
        Button(action: onTapCancel) {
          Text("전체 취소")
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(10)
            .overlay {
              Capsule(style: .continuous)
                .stroke(.black.opacity(0.2), lineWidth: 1)
            }
        }
        .gridCellColumns(4)
        
        Button(action: onTapCheckout) {
          Text("결제하기")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(.blue)
            .clipShape(.capsule(style: .continuous))
        }
        .gridCellColumns(6)
      }
    }
    .padding(.horizontal, 20)
  }
}

#Preview {
  CartActionButtonsView(onTapCancel: {}, onTapCheckout: {})
}
