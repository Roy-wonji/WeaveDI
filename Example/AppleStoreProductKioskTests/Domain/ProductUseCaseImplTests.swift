//
//  ProductUseCaseImplTests.swift
//  AppleStoreProductKioskTests
//
//  Created by Wonji Suh  on 9/17/25.
//

import Testing
@testable import AppleStoreProductKiosk

@MainActor
struct ProductUseCaseImplTests {
  @Test("유스케이스 카탈로그는 레포지토리와 동일하다", .tags(.catalog))
  func useCase_fetchCatalog_matchesMockRepository() async throws {
    let repo = MockProductRepository()
    let useCase = ProductUseCaseImpl(repository: repo)

    let expected = try await repo.fetchProductCatalog()
    let actual = try await useCase.fetchProductCatalog()
    #expect(actual == expected)
  }
  

  @Test("유스케이스로 카테고리 상품을 가져온다", .tags(.products))
  func useCase_fetchProducts_returnsCorrectCount() async throws {
    let repo = MockProductRepository()
    let useCase = ProductUseCaseImpl(repository: repo)

    let products = try await useCase.fetchProducts(for: "Accessories")
    #expect(products.count == 2)
  }
}
