//
//  MockProductRepositoryTests.swift
//  AppleStoreProductKioskTests
//
//  Created by Wonji Suh  on 9/17/25.
//

import Testing
@testable import AppleStoreProductKiosk

@MainActor
struct MockProductRepositoryTests {
  private let repository = MockProductRepository()

  @Test("카탈로그는 기본 카테고리를 포함한다", .tags(.catalog))
  func fetchProductCatalog_hasDefaultCategories() async throws {
    let catalog = try await repository.fetchProductCatalog()
    #expect(!catalog.categories.isEmpty)
    #expect(catalog.categories.count >= 3)
    #expect(catalog.categories.contains { $0.name == "iPhone" })
  }

  @Test("특정 카테고리의 상품을 반환한다", .tags(.products))
  func fetchProducts_returnsProductsForCategory() async throws {
    let products = try await repository.fetchProducts(for: "iPhone")
    #expect(!products.isEmpty)
    #expect(products.contains { $0.name.contains("iPhone") })
  }

  @Test("카테고리 매칭은 대소문자를 구분하지 않는다", .tags(.caseInsensitive))
  func fetchProducts_isCaseInsensitive() async throws {
    let lower = try await repository.fetchProducts(for: "iphone")
    let upper = try await repository.fetchProducts(for: "IPHONE")
    #expect(lower.count == upper.count)
  }
}
