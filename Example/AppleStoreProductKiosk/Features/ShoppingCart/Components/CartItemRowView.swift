//
//  CartItemRowView.swift
//  AppleStoreProductKiosk
//
//  Created by 김민희 on 9/16/25.
//

import SwiftUI

struct CartItem: Identifiable, Equatable {
  let product: Product
  let quantity: Int

  var id: String { product.id }
  var name: String { product.name }
  var price: Double { product.price }
  var imageURL: URL? { product.imageURL }
  var subtotal: Double { product.price * Double(quantity) }

  var formattedPrice: String {
    price.formatted(.currency(code: "KRW"))
  }

  var formattedSubtotal: String {
    subtotal.formatted(.currency(code: "KRW"))
  }
}

struct CartItemRowView: View {
  let item: CartItem
  let onTapDecrease: () -> Void
  let onTapIncrease: () -> Void
  let onTapRemove: () -> Void

  var body: some View {
    HStack(spacing: 20) {
      AsyncImage(url: item.imageURL) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        case .failure:
          placeholderImage
        case .empty:
          ProgressView()
        @unknown default:
          placeholderImage
        }
      }
      .frame(width: 80, height: 80)
      .background(.gray.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .clipped()

      VStack(alignment: .leading, spacing: 8) {
        Text(item.name)
          .font(.system(size: 17, weight: .semibold))

        Text(item.formattedPrice)
          .font(.system(size: 14, weight: .regular))
          .foregroundStyle(.black.opacity(0.7))

        Text("소계: \(item.formattedSubtotal)")
          .font(.system(size: 12, weight: .regular))
          .foregroundStyle(.blue)
      }

      Spacer()

      HStack(spacing: 13) {
        if item.quantity > 1 {
          Button(action: onTapDecrease) {
            Image(systemName: "minus")
              .font(.system(size: 15))
              .padding(12)
              .foregroundStyle(.black)
              .background(.white)
              .clipShape(Circle())
              .overlay(
                Circle()
                  .stroke(.gray.opacity(0.3), lineWidth: 0.7)
              )
          }
        } else {
          Button(action: onTapRemove) {
            Image(systemName: "trash")
              .font(.system(size: 13))
              .padding(8)
              .foregroundStyle(.red)
              .background(.white)
              .clipShape(Circle())
              .overlay(
                Circle()
                  .stroke(.gray.opacity(0.3), lineWidth: 0.7)
              )
          }
        }

        Text("\(item.quantity)")
          .frame(minWidth: 20)

        Button(action: onTapIncrease) {
          Image(systemName: "plus")
            .font(.system(size: 15))
            .padding(7)
            .foregroundStyle(.black)
            .background(.white)
            .clipShape(Circle())
            .overlay(
              Circle()
                .stroke(.gray.opacity(0.3), lineWidth: 0.7)
            )
        }
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 20)
    .background(.gray.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  @ViewBuilder
  private var placeholderImage: some View {
    Image(systemName: "photo")
      .font(.system(size: 26))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .foregroundStyle(.gray.opacity(0.5))
  }
}

#Preview {
  CartItemRowView(
    item: CartItem(product: .iPhone16Pro, quantity: 2),
    onTapDecrease: {},
    onTapIncrease: {},
    onTapRemove: {}
  )
  .padding()
}
