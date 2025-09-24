//
//  ProductInterface.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/16/25.
//

import Foundation

public protocol ProductInterface {
  func fetchProductCatalog() async throws -> ProductCatalog
  func fetchProducts(for category: String) async throws -> [Product]
}
