//
//  URLRequestBuilder.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation
import LogMacro

/// TargetType을 기반으로 URLRequest를 생성하는 빌더 클래스입니다.
///
/// - 파라미터 인코딩, 헤더 설정, URL 조합 등 네트워크 요청 생성의 모든 과정을 담당합니다.
class URLRequestBuilder {
  /// 기본 생성자
  public init() {}

  /// TargetType을 받아 URLRequest를 생성합니다.
  ///
  /// - Parameter target: 네트워크 요청 정보가 담긴 TargetType
  /// - Returns: 완성된 URLRequest
  static func buildRequest(from target: TargetType) -> URLRequest {
    // Base URL과 path를 안전하게 결합 (슬래시 이스케이프 이슈 방지)
    let base = target.baseURL
    var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
    components?.path = target.path.trimmingCharacters(in: .whitespaces)
    var request = URLRequest(url: components?.url ?? base)
    request.httpMethod = target.method.rawValue

    // 헤더 추가
    if let headers = target.headers {
      headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
    }

    // 파라미터 및 인코딩 처리
    switch target.task {
      case .requestParameters(let parameters, let encoding):
        do {
          request = try encoding.encode(request, with: parameters)
        } catch {
          Log.error("Failed to encode parameters: %{public}@", error.localizedDescription)
        }
      case .requestCompositeParameters(
        let bodyParameters,
        let bodyEncoding,
        let urlParameters
      ):
        do {
          components?.queryItems = urlParameters
            .map { URLQueryItem(name: $0.key, value: "\($0.value)") }
          request.url = components?.url
          request = try bodyEncoding.encode(request, with: bodyParameters)
        } catch {
          Log.error("Failed to encode composite parameters: %{public}@", error.localizedDescription)
        }
      case .requestPlain:
        // 파라미터 없이 단순 요청
        components?.queryItems = nil
        request.url = components?.url
    }

    return request
  }
}
