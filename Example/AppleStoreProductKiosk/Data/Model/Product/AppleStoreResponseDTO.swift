//
//  AppleStoreResponseDTO.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/17/25.
//

import Foundation

struct AppleStoreResponseDTO: Decodable {
  let code: Int
  let message: String
  let data: StoreDataDTO
}

struct StoreDataDTO: Decodable {
  let store: StoreInfoDTO
  let categories: [CategoryDTO]
}

struct StoreInfoDTO: Decodable {
  let id: String
  let region: String
  let currency: String
  let updatedAt: String
}

struct CategoryDTO: Decodable {
  let category: String
  let products: [ProductDTO]
}

struct ProductDTO: Decodable {
  let id: String
  let name: String?
  let description: String?
  let fromPrice: PriceDTO
  let links: ProductLinksDTO?
  let images: ProductImagesDTO
}

struct PriceDTO: Decodable {
  let amount: Int
  let currency: String
  let formatted: String
}

struct ProductLinksDTO: Decodable {
  let buy: String?
  let imagePage: String?
}

struct ProductImagesDTO: Decodable {
  let main: String
  let thumbnails: [String]
}
