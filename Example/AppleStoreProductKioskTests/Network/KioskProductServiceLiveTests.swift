//
//  KioskProductServiceLiveTests.swift
//  AppleStoreProductKioskTests
//
//  Created by Wonji Suh  on 9/17/25.
//

import Testing
@testable import AppleStoreProductKiosk

@Suite("실 API 테스트", .tags(.liveAPI, .network, .integration))
struct KioskProductServiceLiveTests {

  @Test("실 API: /products 응답 디코딩 성공")
  func live_fetch_products_decodes() async throws {
    let provider = AsyncProvider<KioskProductService>.conservative()
    let response = try await provider.requestAsync(.getAllProducts, decodeTo: AppleStoreResponseDTO.self)

    #expect(!response.data.categories.isEmpty)
  }

  @Test("실 API: 레포지토리로 도메인 변환 성공")
  func live_repository_fetchCatalog_returnsDomain() async throws {
    let repo = ProductRepositoryImpl()
    let catalog = try await repo.fetchProductCatalog()

    #expect(!catalog.categories.isEmpty)
    // 적어도 하나의 카테고리에 하나 이상의 상품이 있어야 함
    #expect(catalog.categories.contains { !$0.products.isEmpty })
  }
}
