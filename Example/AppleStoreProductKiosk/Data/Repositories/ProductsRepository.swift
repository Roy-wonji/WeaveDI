//
//  ProductsRepository.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/16/25.
//

import Foundation
import DiContainer

public struct DefaultProductsRepository: ProductsRepository {
  public init() {}

  public func fetchProducts() async throws -> ProductCatalog {
    // 임시로 Mock 데이터 반환
    return ProductCatalog(id: "default-catalog", categories: Category.allCategories)
  }
}

extension RegisterModule {
  var productsRepositoryModule: () -> Module {
    makeDependencyImproved(ProductsRepository.self) {
      DefaultProductsRepository()
    }
  }
}
