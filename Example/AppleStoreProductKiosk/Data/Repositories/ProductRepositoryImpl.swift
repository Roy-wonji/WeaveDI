//
// ProductRepositoryImpl.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/16/25.
//

import Combine
import WeaveDI


class ProductRepositoryImpl: ProductInterface , ObservableObject {
  private let provider = AsyncProvider<KioskProductService>(session: .shared)
  
  func fetchProductCatalog() async throws -> ProductCatalog {
    let response = try await provider.requestAsync(.getAllProducts, decodeTo: AppleStoreResponseDTO.self)
    return response.data.toDomain()
  }
  
  func fetchProducts(for category: String) async throws -> [Product] {
    let catalog = try await fetchProductCatalog()
    return catalog.categories
      .first { $0.name.lowercased() == category.lowercased() }?
      .products ?? []
  }
}


extension RegisterModule {
  var productRepositoryImplModule: @Sendable () -> Module {
    makeDependencyImproved(ProductInterface.self) {
      ProductRepositoryImpl()
    }
  }
}
