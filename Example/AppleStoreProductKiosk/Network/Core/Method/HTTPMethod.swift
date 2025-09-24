//
//  HTTPMethod.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

/// HTTP 요청에서 사용되는 메서드 타입을 정의한 enum입니다.
enum HTTPMethod: String {
  /// GET: 데이터 조회
  case get = "GET"
  /// POST: 데이터 생성
  case post = "POST"
  /// PUT: 데이터 전체 수정
  case put = "PUT"
  /// DELETE: 데이터 삭제
  case delete = "DELETE"
}

