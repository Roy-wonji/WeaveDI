//
//  APIHeader.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

// API 요청에 사용되는 공통 헤더 키를 정의하는 구조체입니다.
enum APIHeader {
  /// Content-Type 헤더 키
  static let contentType   = "Content-Type"

}


extension APIHeader {

  /// 인증 토큰이 필요 없는 기본 헤더
  public static var baseHeader: [String: String] {
    [
      contentType: APIHeaderManager.contentType
    ]
  }

}
