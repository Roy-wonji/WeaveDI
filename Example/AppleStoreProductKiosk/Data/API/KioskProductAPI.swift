//
//  KioskProductAPI.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

// MARK: - KioskAPI Namespace

/// Kiosk API의 네임스페이스
///
/// Kiosk 관련 API 엔드포인트만을 관리하는 단일 책임을 가집니다.
enum KioskAPI {
  
  // MARK: - Product API
  
  /// 상품 관련 API 엔드포인트
  enum Product: APIEndpoint {
    case list
    
    var basePath: String {
      return APIDomain.kiosk.basePath
    }
    
    var path: String {
      switch self {
        case .list:
          return "/products"
      }
    }
  }
}
