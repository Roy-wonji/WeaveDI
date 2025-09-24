//
//  ProductListFeatureTests.swift
//  AppleStoreProductKioskTests
//
//  Created by 홍석현 on 9/17/25.
//

import Foundation
import ComposableArchitecture
import Testing

@testable import AppleStoreProductKiosk

@MainActor
struct ProductListFeatureTests {
  @Test
  func onAppear_호출시_상품데이터를_가져오고_카테고리를_초기화한다() async {
    let initialSelected = Shared<[Product]>(value: [])
    let store = TestStore(
      initialState: ProductListFeature.State(
        selectedProducts: initialSelected
      )
    ) {
      ProductListFeature()
    }
    
    await store.send(.view(.onAppear))
    
    await store.receive(\.async.fetchProductData)
    await store.receive(\.inner.updateProductCategories) {
      $0.productCategories = IdentifiedArray(uniqueElements: Category.allCategories)
    }
    await store.receive(\.inner.updateSelectedCategoryId) {
      $0.currentSelectedCategoryId = Category.allCategories.first!.id
      // 계산 프로퍼티 결과 검증
      let expectedItems = Category.allCategories.first!.products
      #expect($0.currentItems == IdentifiedArray(uniqueElements: expectedItems))
    }
  }
  
  @Test
  func onTapCategoryButton_호출시_현재상품들이업데이트된다() async {
    let initialSelected = Shared<[Product]>(value: [])
    let store = TestStore(
      initialState: ProductListFeature.State(
        selectedProducts: initialSelected
      )
    ) {
      ProductListFeature()
    }
    
    store.exhaustivity = .off(showSkippedAssertions: false)
    
    await store.send(.async(.fetchProductData))
    
    await store.send(.view(.onTapCategory(id: Category.AirPods.id)))

    await store.receive(\.inner.updateSelectedCategoryId) {
      $0.currentSelectedCategoryId = Category.AirPods.id

      let expectedItems = Category.AirPods.products
      #expect($0.currentItems == IdentifiedArray(uniqueElements: expectedItems))
    }
  }
  
  @Test
  func onTapAddItem_호출시_selectedProduct에_아이템이_추가된다() async {
    let initialSelected = Shared<[Product]>(value: [])
    let store = TestStore(
      initialState: ProductListFeature.State(
        selectedProducts: initialSelected
      )
    ) {
      ProductListFeature()
    }
    
    store.exhaustivity = .off(showSkippedAssertions: false)
    
    // 2) 데이터 로드 및 초기 카테고리 선택까지 진행
    await store.send(.view(.onAppear))
    
    // 3) 현재 카테고리의 첫 상품 선택
    let firstItemId = Category.allCategories.first!.products.first!.id

    // 4) 아이템 추가 액션 전송 → selectedProduct가 업데이트되는지 검증
    await store.send(.view(.onTapAddItem(id: firstItemId))) {
      // 상태 스냅샷 기반 검증
      let expected = [Category.allCategories.first!.products.first!]
      $0.$selectedProducts.withLock { $0 = expected }
    }
  }
  
  @Test
  func onTapAddItem_두번호출시_selectedProduct가_누적된다() async {
    let initialSelected = Shared<[Product]>(value: [])
    let store = TestStore(
      initialState: ProductListFeature.State(
        selectedProducts: initialSelected
      )
    ) {
      ProductListFeature()
    }
    
    store.exhaustivity = .off(showSkippedAssertions: false)
    
    await store.send(.view(.onAppear))

    let firstCategory = Category.allCategories.first!
    
    let p1 = firstCategory.products[0]
    let p2 = firstCategory.products[1]
    
    await store.send(.view(.onTapAddItem(id: p1.id))) {
      $0.$selectedProducts.withLock { $0 = [p1] }
    }
    await store.send(.view(.onTapAddItem(id: p2.id))) {
      $0.$selectedProducts.withLock { $0 = [p1, p2] }
    }
  }
}


@MainActor
struct ProductList_CartButton_SharedIntegrationTests {
  // 부모에서 아이템 추가 → 자식의 totalPrice에 즉시 반영
  @Test
  func parentAddsItem_childTotalPriceUpdates() async {
    // 1) 초기 상태 구성: Shared 주입 및 자식 생성
    let shared = Shared<[Product]>(value: [])
    let initial = ProductListFeature.State(
      selectedProducts: shared
    )
    let store = TestStore(initialState: initial) { ProductListFeature() }

    // 2) 데이터 로드로 현재 카테고리/아이템 확보
    await store.send(.view(.onAppear))
    await store.receive(\.async.fetchProductData)
    await store.receive(\.inner.updateProductCategories) {
      $0.productCategories = IdentifiedArray(uniqueElements: Category.allCategories)
    }
    let firstCategory = Category.allCategories.first!
    await store.receive(\.inner.updateSelectedCategoryId) {
      $0.currentSelectedCategoryId = firstCategory.id
    }

    // 3) 부모 액션으로 아이템 추가
    let p1 = firstCategory.products.first!
    await store.send(.view(.onTapAddItem(id: p1.id))) {
      // 공유 상태가 [p1]로 바뀐다
      $0.$selectedProducts.withLock { $0 = [p1] }
      // 자식은 Shared를 읽기만 해도 totalPrice가 반영되어야 함
      #expect($0.cartButtonState.totalPrice == p1.price)
    }
  }
}
