//
//  BaseTargetType.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

/// API 타겟의 공통 속성을 정의하는 프로토콜입니다.
///
/// - 도메인, URL 경로, 파라미터 등 API 요청에 필요한 정보를 제공합니다.
protocol BaseTargetType: TargetType {
  /// API 엔드포인트
  var endpoint: any APIEndpoint { get }
  /// 요청 파라미터
  var parameters:[String: Any]? { get }
}

// MARK: - BaseTargetType 기본 구현


extension BaseTargetType {
  /// API의 baseURL
  var baseURL: URL {
    return URL(string: endpoint.baseURL)!
  }

  /// 전체 path
  var path: String {
    return endpoint.fullPath
  }

  /// 기본 헤더 (인증 없는 헤더 사용)
  var headers: [String : String]? {
    return APIHeader.baseHeader
  }

  /// 네트워크 요청 Task (파라미터 유무/메서드에 따라 인코딩 방식 분기)
  var task: NetworkTask {
    if let parameters = parameters {
      if method == .get {
        return .requestParameters(
          parameters: parameters,
          encoding: .url
        )
      } else {
        return .requestParameters(
          parameters: parameters,
          encoding: .json
        )
      }
    } else {
      return .requestPlain
    }
  }
}

