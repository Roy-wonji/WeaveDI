//
//  MockProductRepository.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/17/25.
//

import Foundation

class MockProductRepository: ProductInterface, ProductsRepository {
  private let categoriesData: [Category]

  init(categories: [Category]? = nil) {
    if let categories {
      self.categoriesData = categories
    } else {
      self.categoriesData = Category.allCategories
    }
  }

  func fetchProductCatalog() async throws -> ProductCatalog {
    .init(id: "mock-catalog", categories: categoriesData)
  }

  func fetchProducts(for category: String) async throws -> [Product] {
    let lowercased = category.lowercased()
    return categoriesData.first { $0.name.lowercased() == lowercased }?.products ?? []
  }

  func fetchProducts() async throws -> ProductCatalog {
    return ProductCatalog(id: "mock-catalog", categories: categoriesData)
  }
}

// MARK: - Default Mock Data는 Category.allCategories 사용
