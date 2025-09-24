//
//  URLSessionLogger.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation
import LogMacro

/// URLSession 네트워크 요청/응답을 콘솔에 로그로 출력하는 싱글턴 유틸리티입니다.
///
/// - DEBUG 모드에서만 동작하며, 요청/응답의 메서드, URL, 헤더, 바디, 에러 등을 보기 좋게 출력합니다.
final class URLSessionLogger {
  /// 싱글턴 인스턴스
  static let shared = URLSessionLogger()

  /// 외부에서 직접 생성하지 못하도록 private init
  private init() {}

  // MARK: - 요청 로그

  /// 네트워크 요청 정보를 콘솔에 출력합니다.
  /// - Parameter request: 로깅할 URLRequest
  @MainActor
  func logRequest(_ request: URLRequest) {
#if DEBUG
    Log.debug("⎡--------------------- REQUEST ---------------------⎤")

    // HTTP 메서드
    if let method = request.httpMethod {
      Log.network("[Method]", method)
    }

    // 요청 URL
    if let url = request.url?.absoluteString {
      Log.network("[URL]", url)
    }

    // 헤더
    if let headers = request.allHTTPHeaderFields {
      Log.network("[Headers]")
      for (key, value) in headers {
        Log.network("  \(key): \(value)")
      }
    }

    // 바디
    if let body = request.httpBody,
       let bodyString = String(data: body, encoding: .utf8) {
      Log.network("[Body]")
      Log.network("  \(bodyString)")
    }

    Log.network("⎣------------------ END REQUEST --------------------⎦")
#endif
  }

  // MARK: - 응답 로그

  /// 네트워크 응답 정보를 콘솔에 출력합니다.
  /// - Parameters:
  ///   - data: 응답 데이터
  ///   - response: URLResponse 객체
  ///   - error: 네트워크 에러
  @MainActor
  func logResponse(data: Data?, response: URLResponse?, error: Error?) {
#if DEBUG
    Log.network("⎡--------------------- RESPONSE --------------------⎤")

    // 응답 URL
    if let url = response?.url?.absoluteString {
      Log.network("[URL]", url)
    }

    // HTTP 상태 코드 및 헤더
    if let httpResponse = response as? HTTPURLResponse {
      Log.network("[Status Code] \(httpResponse.statusCode)")
      Log.network("[Response Headers]")
      for (key, value) in httpResponse.allHeaderFields {
        Log.network("  \(key): \(value)")
      }
    }

    // 바디 (JSON pretty print 시도, 실패 시 raw 출력)
    if let data = data {
      do {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        let prettyData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        if let prettyString = String(data: prettyData, encoding: .utf8) {
          Log.network("[Body (Map)]")
          Log.network(prettyString)
        }
      } catch {
        // JSON 디코딩 실패 시 원본 문자열 출력
        if let rawString = String(data: data, encoding: .utf8) {
          Log.network("[Body (Raw)]")
          Log.network(rawString)
        } else {
          Log.network("[Body] Cannot decode data")
        }
      }
    }

    // 에러
    if let error = error {
      Log.network("[Error] \(error.localizedDescription)")
    }

    Log.network("⎣------------------ END RESPONSE -------------------⎦")
#endif
  }
}
