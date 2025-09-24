//
//  CustomParameterEncoding.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

/// URLRequest의 파라미터 인코딩 방식을 정의하는 enum입니다.
///
/// - url: 쿼리 파라미터로 인코딩 (GET 등)
/// - json: HTTP Body에 JSON으로 인코딩 (POST, PUT 등)
enum CustomParameterEncoding {
  case url
  case json

  /// 파라미터를 주어진 URLRequest에 인코딩하여 반환합니다.
  ///
  /// - Parameters:
  ///   - request: 인코딩할 URLRequest
  ///   - parameters: 인코딩할 파라미터 딕셔너리
  /// - Returns: 파라미터가 인코딩된 URLRequest
  /// - Throws: 인코딩 실패 시 에러(DataError)
  func encode(_ request: URLRequest, with parameters: [String: Any]) throws -> URLRequest {
    var request = request
    switch self {
    case .url:
      // URL 쿼리 파라미터로 인코딩
      guard let url = request.url else {
        throw DataError.customError("Invalid URL")
      }
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      components?.queryItems = parameters
        .map { URLQueryItem(name: $0.key, value: "\($0.value)") }
      request.url = components?.url
    case .json:
      // HTTP Body에 JSON으로 인코딩
      let jsonData = try JSONSerialization.data(
        withJSONObject: parameters,
        options: []
      )
      request.httpBody = jsonData
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    return request
  }
}

