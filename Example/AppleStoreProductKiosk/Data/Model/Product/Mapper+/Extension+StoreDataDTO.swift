//
//  Extension+StoreDataDTO.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/17/25.
//

import Foundation

extension StoreDataDTO {
  func toDomain() -> ProductCatalog {
    let categories = categories.map { categoryDTO in
      let products = categoryDTO.products.map { productDTO in
        let productName = productDTO.name ?? productDTO.id.replacingOccurrences(of: "-", with: " ").capitalized
        let productDescription = productDTO.description ?? "제품 설명이 없습니다."

        return Product(
          id: productDTO.id,
          name: productName,
          description: productDescription,
          price: Double(productDTO.fromPrice.amount),
          imageURL: URL(string: productDTO.images.main)
        )
      }

      return Category(
        name: categoryDTO.category,
        products: products
      )
    }

    return ProductCatalog(id: "store-catalog", categories: categories)
  }
}
