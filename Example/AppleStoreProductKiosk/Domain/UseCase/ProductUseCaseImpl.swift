//
//  ProductUseCaseImpl.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/16/25.
//

import Foundation

import ComposableArchitecture
import DiContainer

public struct ProductUseCaseImpl: ProductInterface {
  private let repository: ProductInterface

  public  init(repository: ProductInterface) {
    self.repository = repository
  }

  // MARK: - 카테고리들 전체 가지고오기
  public func fetchProductCatalog() async throws -> ProductCatalog {
    return try await repository.fetchProductCatalog()
  }

  // MARK: -특정 카테고리 가져오기
  public func fetchProducts(for category: String) async throws -> [Product] {
    return try await repository.fetchProducts(for: category)
  }
}

extension DependencyContainer {
  var productInterface: ProductInterface? {
    resolve(ProductInterface.self)
  }
}

extension ProductUseCaseImpl: DependencyKey {
  public static var liveValue: ProductInterface {
    let repository =  UnifiedDI.register(\.productInterface) {
      ProductRepositoryImpl()
    }
    return ProductUseCaseImpl(repository: repository)
  }
  public static var testValue: ProductInterface = MockProductRepository()
}

public extension DependencyValues {
  var productUseCase: ProductInterface {
    get { self[ProductUseCaseImpl.self] }
    set { self[ProductUseCaseImpl.self] = newValue }
  }
}

extension RegisterModule {
  var productUseCaseImplModule: () -> Module {
    makeUseCaseWithRepository(
      ProductInterface.self,
      repositoryProtocol: ProductInterface.self,
      repositoryFallback: MockProductRepository(),
      factory: { repo in
        ProductUseCaseImpl(repository: repo)
      }
    )
  }
}
