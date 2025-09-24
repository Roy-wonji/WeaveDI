//
//  ProductRepositoryProtocol.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/16/25.
//

import Foundation

public protocol ProductsRepository {
  func fetchProducts() async throws -> ProductCatalog
}
