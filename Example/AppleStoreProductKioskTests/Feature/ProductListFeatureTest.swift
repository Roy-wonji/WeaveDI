//
//  ProductListFeatureTest.swift
//  AppleStoreProductKioskTests
//
//  Created by Wonji Suh  on 9/17/25.
//

import Testing
import ComposableArchitecture
@testable import AppleStoreProductKiosk

@Suite("ProductListFeatureTest", .tags(.feature, .productList))
@MainActor
struct ProductListFeatureTest {

  @Test("onAppear 시 카탈로그 로드 및 상태 업데이트", .tags(.load))
  func loadCatalog_onAppear_updatesState() async throws {
    // Expected categories from the mock repository
    let expectedCatalog = try await MockProductRepository().fetchProductCatalog()

    let selected = Shared<[Product]>(value: [])
    let store = TestStore(initialState: ProductListFeature.State(selectedProducts: selected)) {
      ProductListFeature()
    } withDependencies: {
      $0.productUseCase = ProductUseCaseImpl.testValue
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.fetchProductData)
    await store.receive(\.inner.updateProductCategories) { state in
      state.productCategories = IdentifiedArray(uniqueElements: expectedCatalog.categories)
    }
    await store.receive(\.inner.updateSelectedCategoryId) { state in
      state.currentSelectedCategoryId = expectedCatalog.categories.first?.id ?? ""
    }
  }

  @Test("카탈로그 로드 실패 시 상태는 변경되지 않는다", .tags(.error))
  func loadCatalog_failure_keepsStateAndShowsAlert() async throws {
    struct ThrowingUseCase: ProductInterface {
      func fetchProductCatalog() async throws -> ProductCatalog { throw DataError.customError("boom") }
      func fetchProducts(for category: String) async throws -> [Product] { [] }
    }

    let selected = Shared<[Product]>(value: [])
    let store = TestStore(initialState: ProductListFeature.State(selectedProducts: selected)) {
      ProductListFeature()
    } withDependencies: {
      $0.productUseCase = ThrowingUseCase()
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.fetchProductData)
    await store.receive(\.inner.showErrorAlert)

    #expect(store.state.productCategories.isEmpty)
    #expect(store.state.alert != nil)
  }

  @Test("상품 추가 탭은 현재 상태를 변경하지 않는다", .tags(.action))
  func onTapAddProduct_noStateChange_whenInvalidID() async throws {
    let selected = Shared<[Product]>(value: [])
    let initial = ProductListFeature.State(selectedProducts: selected)
    let store = TestStore(initialState: initial) {
      ProductListFeature()
    } withDependencies: {
      $0.productUseCase = ProductUseCaseImpl.testValue
    }

    await store.send(.view(.onTapAddItem(id: "some-id")))
    // Invalid id should not change any observable state
    #expect(store.state.productCategories == initial.productCategories)
    #expect(store.state.currentSelectedCategoryId == initial.currentSelectedCategoryId)
    #expect(store.state.isHiddenCartButton == initial.isHiddenCartButton)
  }

  @Test("카테고리 선택 시 상품 목록 로드", .tags(.load))
  func selectCategory_updatesCurrentItems() async throws {
    // Arrange: load catalog first so categories are present
    let repo = MockProductRepository()
    let expectedProducts = try await repo.fetchProducts(for: "iPhone")

    let selected = Shared<[Product]>(value: [])
    let store = TestStore(initialState: ProductListFeature.State(selectedProducts: selected)) {
      ProductListFeature()
    } withDependencies: {
      $0.productUseCase = ProductUseCaseImpl.testValue
    }

    await store.send(.view(.onAppear))
    _ = await store.receive(\.async.fetchProductData)
    _ = await store.receive(\.inner.updateProductCategories)
    _ = await store.receive(\.inner.updateSelectedCategoryId)

    // Act: select iPhone category by id
    let categoryId = Category.iPhone.id
    await store.send(.view(.onTapCategory(id: categoryId)))
    await store.receive(\.inner.updateSelectedCategoryId) { state in
      state.currentSelectedCategoryId = categoryId
    }

    // Assert: currentItems matches expected iPhone products
    #expect(Array(store.state.currentItems) == expectedProducts)
  }
}
