//
//  APIDomain.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

// MARK: - API Domain Types

/// API 도메인 타입 정의
///
/// 각 도메인별 basePath를 관리하는 단일 책임을 가집니다.
enum APIDomain {
  case kiosk
  
  var basePath: String {
    switch self {
      case .kiosk:
        return "/api/apple-store-kiosk"
    }
  }
}
