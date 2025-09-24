//
//  NetworkTask.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

/// 네트워크 요청 시 사용할 파라미터 인코딩 및 전송 방식을 정의하는 enum입니다.
enum NetworkTask {
  /// 파라미터 없이 단순 요청 (GET, DELETE 등)
  case requestPlain

  /// 파라미터와 인코딩 방식이 있는 요청 (주로 GET, POST 등)
  case requestParameters(
    parameters: [String: Any],
    encoding: CustomParameterEncoding
  )

  /// URL 파라미터와 Body 파라미터를 모두 포함하는 복합 요청
  /// (예: 쿼리 + 바디 동시 필요 시)
  case requestCompositeParameters(
    bodyParameters: [String: Any],
    bodyEncoding: CustomParameterEncoding,
    urlParameters: [String: Any]
  )
}

