//
//  CartHeaderView.swift
//  AppleStoreProductKiosk
//
//  Created by 김민희 on 9/16/25.
//

import SwiftUI

struct CartHeaderView: View {
  @Environment(\.dismiss) var dismiss

  var body: some View {
    HStack(spacing: 0) {
      Text("장바구니")
        .font(.system(size: 20, weight: .bold))
      Spacer()

      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .foregroundColor(.black)
          .font(.system(size: 15))
          .padding(8)
          .background(.gray.opacity(0.15))
          .clipShape(Circle())
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 25)
  }
}

#Preview {
  CartHeaderView()
}
