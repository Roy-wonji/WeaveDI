//
//  ProductCardView.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/16/25.
//

import SwiftUI

public struct ProductCardView: View {
  private enum Layout {
    static let imageHeight: CGFloat = 120
    static let textAreaHeight: CGFloat = 55
    static let cornerRadius: CGFloat = 8
    static let cardPadding: CGFloat = 10
    static let buttonPadding: CGFloat = 4
  }
  private let id: String
  private let imageURL: URL?
  private let title: String
  private let subTitle: String
  private let price: Double
  private var onTapAction: ((String) -> Void)?
  
  public init(
    product: Product,
    onTapAction: ((String) -> Void)? = nil
  ) {
    self.id = product.id
    self.imageURL = product.imageURL
    self.title = product.name
    self.subTitle = product.description
    self.price = product.price
    self.onTapAction = onTapAction
  }
  
  public var body: some View {
    VStack(spacing: 8) {
      AsyncImage(url: self.imageURL) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fit)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.2))
          .clipShape(
            RoundedRectangle(
              cornerRadius: Layout.cornerRadius
            )
          )
          .overlay(
            ProgressView()
              .scaleEffect(0.8)
          )
      }
      .frame(height: Layout.imageHeight)
      .clipped()
      
      VStack(alignment: .leading, spacing: 8) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
            .foregroundStyle(Color.primary)
            .lineLimit(1)
          
          Text(subTitle)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(Color.secondary)
            .lineLimit(2)
        }
        .frame(height: Layout.textAreaHeight, alignment: .leading)

        Text(price.formattedKRWCurruncy)
          .font(.system(size: 20, weight: .semibold))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      
      Button {
        onTapAction?(self.id)
      } label: {
        Text("담기")
          .foregroundStyle(Color.white)
          .font(.system(size: 14, weight: .bold))
          .frame(maxWidth: .infinity)
      }
      .padding(.vertical, Layout.buttonPadding)
      .padding(.horizontal, Layout.cardPadding)
      .background(Color.accentColor)
      .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    }
    .padding(Layout.cardPadding)
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    .shadow(radius: 0.5)
  }
}

#Preview {
  VStack(spacing: 16) {
    HStack(spacing: 16) {
      ProductCardView(
        product: Product.AirPods4
      )

      ProductCardView(
        product: Product.AppleWatchSE3
      )
    }

    HStack(spacing: 16) {
      ProductCardView(
        product: Product.AppleWatchSeries11
      )

      ProductCardView(
        product: Product.AppleVisionPro
      )
    }
  }
  .padding()
}
