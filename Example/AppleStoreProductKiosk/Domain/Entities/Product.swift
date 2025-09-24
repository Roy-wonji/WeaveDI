//
//  Product.swift
//  AppleStoreProductKiosk
//
//  Created by 홍석현 on 9/16/25.
//

import Foundation

// MARK: - 제품 엔티티
public struct Product: Identifiable, Equatable {
  public let id: String
  public let name: String
  public let description: String
  public let price: Double
  public let imageURL: URL?
  
  public init(
    id: String,
    name: String,
    description: String,
    price: Double,
    imageURL: URL?
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.price = price
    self.imageURL = imageURL
  }
}

// MARK: - 카테고리 엔티티
public struct Category: Identifiable, Equatable {
  public let id: String
  public let name: String
  public let products: [Product]

  public init(
    id: String,
    name: String,
    products: [Product]
  ) {
    self.id = id
    self.name = name
    self.products = products
  }

  public init(name: String, products: [Product]) {
    self.id = name.lowercased().replacingOccurrences(of: " ", with: "-")
    self.name = name
    self.products = products
  }
}

// MARK: - 제품 카탈로그 엔티티
public struct ProductCatalog: Identifiable, Equatable {
  public let id: String
  public let categories: [Category]

  public init(id: String, categories: [Category]) {
    self.id = id
    self.categories = categories
  }
}

// MARK: - Mock 데이터
public extension Product {
  
  // MARK: - iPhone 제품들
  static let iPhone16 = Product(
    id: "iphone-16",
    name: "iPhone 16",
    description: "갖고 싶던 iPhone. 이제 당신의 취향대로",
    price: 1150000,
    imageURL: URL(string: "https://store.storeimages.cdn-apple.com/8756/as-images.apple.com/is/iphone-16-plus-finish-select-202409-6-7inch-ultramarine?wid=5120&hei=2880&fmt=p-jpg&qlt=80&.v=1723674442922")!
  )
  
  static let iPhone16Plus = Product(
    id: "iphone-16-plus",
    name: "iPhone 16 Plus",
    description: "갖고 싶던 iPhone. 이제 당신의 취향대로",
    price: 1290000,
    imageURL: URL(string: "https://store.storeimages.cdn-apple.com/8756/as-images.apple.com/is/iphone-16-plus-finish-select-202409-6-7inch-ultramarine?wid=5120&hei=2880&fmt=p-jpg&qlt=80&.v=1723674442922")!
  )
  
  static let iPhone16Pro = Product(
    id: "iphone-16-pro",
    name: "iPhone 16 Pro",
    description: "갖고 싶던 iPhone. 이제 당신의 취향대로",
    price: 1550000,
    imageURL: URL(string: "https://www.apple.com/newsroom/images/2024/09/apple-debuts-iphone-16-pro-and-iphone-16-pro-max/article/Apple-iPhone-16-Pro-hero-geo-240909_inline.jpg.large.jpg")!
  )
  
  static let iPhone16e = Product(
    id: "iphone-16e",
    name: "iPhone 16e",
    description: "갖고 싶던 iPhone. 이제 당신의 취향대로",
    price: 990000,
    imageURL: URL(string: "https://store.storeimages.cdn-apple.com/8756/as-images.apple.com/is/iphone-se-finish-select-202204-midnight?wid=5120&hei=2880&fmt=p-jpg&qlt=80&.v=1646415838921")!
  )
  
  // MARK: - MacBook 제품들
  static let MacBookAir13M4 = Product(
    id: "macbook-air-13-m4",
    name: "MacBook Air 13 (M4)",
    description: "갖고 싶던 MacBook Air. 이제 당신의 취향대로",
    price: 1890000,
    imageURL: URL(string: "https://www.apple.com/newsroom/images/2025/03/apple-introduces-macbook-air-with-m4/article/Apple-MacBook-Air-hero-250305_big.jpg.large.jpg")!
  )
  
  static let MacBookAir15M4 = Product(
    id: "macbook-air-15-m4",
    name: "MacBook Air 15 (M4)",
    description: "갖고 싶던 MacBook Air. 이제 당신의 취향대로",
    price: 2190000,
    imageURL: URL(string: "https://www.apple.com/newsroom/images/2025/03/apple-introduces-macbook-air-with-m4/article/Apple-MacBook-Air-open-250305_big.jpg.large.jpg")!
  )
  
  static let MacBookPro14M4 = Product(
    id: "macbook-pro-14-m4",
    name: "MacBook Pro 14 (M4)",
    description: "갖고 싶던 MacBook Pro. 이제 당신의 취향대로",
    price: 2190000,
    imageURL: URL(string: "https://www.apple.com/newsroom/images/2024/10/new-macbook-pro/article/Apple-MacBook-Pro-M4-lifestyle-01_big.jpg.large.jpg")!
  )
  
  // MARK: - Apple Watch 제품들
  static let AppleWatchSeries11 = Product(
    id: "apple-watch-series-11",
    name: "Apple Watch Series 11",
    description: "갖고 싶던 Apple Watch. 이제 당신의 취향대로",
    price: 599000,
    imageURL: URL(string: "https://www.apple.com/newsroom/images/2025/09/apple-debuts-apple-watch-series-11-featuring-groundbreaking-health-insights/article/Apple-Watch-Series-11-hero-250909_big.jpg.large.jpg")!
  )
  
  static let AppleWatchUltra3 = Product(
    id: "apple-watch-ultra-3",
    name: "Apple Watch Ultra 3",
    description: "갖고 싶던 Apple Watch. 이제 당신의 취향대로",
    price: 1249000,
    imageURL: URL(string: "https://www.apple.com/newsroom/images/2025/09/introducing-apple-watch-ultra-3/images/og/Apple-Watch-Ultra-3-hero-250909_big.jpg.large.jpg")!
  )
  
  static let AppleWatchSE3 = Product(
    id: "apple-watch-se-3",
    name: "Apple Watch SE 3",
    description: "갖고 싶던 Apple Watch. 이제 당신의 취향대로",
    price: 369000,
    imageURL: URL(string: "https://www.apple.com/newsroom/images/2025/09/apple-introduces-apple-watch-se-3/article/Apple-Watch-SE-3-hero-250909_big.jpg.large.jpg")!
  )
  
  // MARK: - AirPods 제품들
  static let AirPods4 = Product(
    id: "airpods-4-usbc",
    name: "AirPods 4 (USB-C)",
    description: "갖고 싶던 AirPods. 이제 당신의 취향대로",
    price: 199000,
    imageURL: URL(string: "https://store.storeimages.cdn-apple.com/8756/as-images.apple.com/is/airpods-4-down-compare-202409?wid=500&hei=420&fmt=jpeg&qlt=90&.v=1724255052732")!
  )
  
  static let AirPodsPro3 = Product(
    id: "airpods-pro-3",
    name: "AirPods Pro 3",
    description: "갖고 싶던 AirPods. 이제 당신의 취향대로",
    price: 369000,
    imageURL: URL(string: "https://www.apple.com/newsroom/images/2025/09/introducing-airpods-pro-3-the-ultimate-audio-experience/article/Apple-AirPods-Pro-3-hero-250909_inline.jpg.large.jpg")!
  )
  
  static let AirPodsMax = Product(
    id: "airpods-max-usbc",
    name: "AirPods Max (USB-C)",
    description: "갖고 싶던 AirPods. 이제 당신의 취향대로",
    price: 769000,
    imageURL: URL(string: "https://mars-images-ix-assets-apple-com.akamaized.net/v1/arm64_2/iphone13plus/images/overview/hero/airpods_max__12gkjha.png")!
  )
  
  // MARK: - Vision 제품
  static let AppleVisionPro = Product(
    id: "apple-vision-pro",
    name: "Apple Vision Pro",
    description: "갖고 싶던 Apple Vision Pro. 이제 당신의 취향대로",
    price: 4990000,
    imageURL: URL(string: "https://www.apple.com/newsroom/images/2024/01/apple-vision-pro-available-in-the-us-on-february-2/article/Apple-Vision-Pro-availability-hero_big.jpg.large.jpg")!
  )
  
  // MARK: - 전체 제품 목록
  static let allProducts: [Product] = [
    // iPhone
    iPhone16, iPhone16Plus, iPhone16Pro, iPhone16e,
    // MacBook
    MacBookAir13M4, MacBookAir15M4, MacBookPro14M4,
    // Apple Watch
    AppleWatchSeries11, AppleWatchUltra3, AppleWatchSE3,
    // AirPods
    AirPods4, AirPodsPro3, AirPodsMax,
    // Vision
    AppleVisionPro
  ]
  
  // MARK: - 카테고리별 제품
  static let iPhoneProducts: [Product] = [
    iPhone16, iPhone16Plus, iPhone16Pro, iPhone16e
  ]
  
  static let MacBookProducts: [Product] = [
    MacBookAir13M4, MacBookAir15M4, MacBookPro14M4
  ]
  
  static let AppleWatchProducts: [Product] = [
    AppleWatchSeries11, AppleWatchUltra3, AppleWatchSE3
  ]
  
  static let AirPodsProducts: [Product] = [
    AirPods4, AirPodsPro3, AirPodsMax
  ]
  
  static let VisionProducts: [Product] = [
    AppleVisionPro
  ]
}

// MARK: - 카테고리 Mock 데이터
public extension Category {

  // MARK: - 개별 카테고리들
  static let iPhone = Category(
    id: "iphone",
    name: "iPhone",
    products: Product.iPhoneProducts
  )

  static let MacBook = Category(
    id: "macbook",
    name: "MacBook",
    products: Product.MacBookProducts
  )

  static let AppleWatch = Category(
    id: "apple-watch",
    name: "Apple Watch",
    products: Product.AppleWatchProducts
  )

  static let AirPods = Category(
    id: "airpods",
    name: "AirPods",
    products: Product.AirPodsProducts
  )

  static let Vision = Category(
    id: "vision",
    name: "Vision",
    products: Product.VisionProducts
  )

  // MARK: - 전체 카테고리 목록
  static let allCategories: [Category] = [
    iPhone, MacBook, AppleWatch, AirPods, Vision
  ]
}
