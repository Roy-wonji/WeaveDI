//
//  TargetType.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation


/// 네트워크 API 요청을 추상화하는 프로토콜입니다.
///
/// - 각 API 엔드포인트별로 이 프로토콜을 채택한 enum/struct를 만들면
///   공통적인 네트워크 요청 빌드가 가능합니다.
protocol TargetType {
  /// 기본 도메인 URL (예: https://api.example.com)
  var baseURL: URL { get }

  /// 엔드포인트 경로 (예: "/books/search")
  var path: String { get }

  /// HTTP 메서드 (GET, POST 등)
  var method: HTTPMethod { get }

  /// HTTP 헤더 (필요 시)
  var headers: [String: String]? { get }

  /// 파라미터 및 인코딩 방식 등 요청 작업
  var task: NetworkTask { get }
}

