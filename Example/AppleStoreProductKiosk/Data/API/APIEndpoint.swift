//
//  APIEndpoint.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

// MARK: - APIEndpoint Protocol

/// API 엔드포인트의 공통 속성을 정의하는 프로토콜
protocol APIEndpoint {
  var baseURL: String { get }
  var basePath: String { get }
  var path: String { get }
  var fullPath: String { get }
  var fullURL: String { get }
}

// MARK: - APIEndpoint Default Implementation

extension APIEndpoint {
  var baseURL: String {
    "https://applestoreproductkiosk.free.beeceptor.com"
  }
  
  var fullPath: String {
    basePath + path
  }
  
  var fullURL: String {
    baseURL + fullPath
  }
}
