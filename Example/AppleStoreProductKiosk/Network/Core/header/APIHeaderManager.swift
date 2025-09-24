//
//  APIHeaderManager.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

/// API 헤더의 값(컨텐츠 타입 등)을 관리하는 enum입니다.
enum APIHeaderManager {
  /// 앱 패키지명(필요 시 사용, 기본값 "-")
  static let appPackageName: String = "-"
  /// Content-Type 값 (기본: application/json)
  static let contentType: String = "application/json"
}
