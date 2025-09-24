//
//  DataError.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

/// 네트워크 및 데이터 처리 과정에서 발생할 수 있는 오류를 정의한 enum입니다.
// NOTE: Moved to Network/Core/Errors to avoid Infra -> Data reverse dependency.
enum DataError: Error, LocalizedError, Sendable {
  /// 데이터가 없음
  case noData

  /// 커스텀 에러 메시지
  case customError(String)

  /// 처리하지 않은 HTTP 상태 코드
  case unhandledStatusCode(Int)

  /// HTTP 응답 오류 (응답 객체, 에러 메시지)
  case httpResponseError(HTTPURLResponse, String)

  /// 디코딩 에러
  case decodingError(Error)

  /// 사용자에게 표시할 에러 메시지
  var errorDescription: String? {
    switch self {
    case .noData:
      return "데이터를 받지 못했습니다"
    case .customError(let message):
      return message
    case .unhandledStatusCode(let code):
      return "처리되지 않은 상태 코드: \(code)"
    case .httpResponseError(let response, let message):
      return "HTTP \(response.statusCode): \(message)"
    case .decodingError(let error):
      return "디코딩 실패: \(error.localizedDescription)"
    }
  }
}


extension DataError: Equatable {
  static func == (lhs: DataError, rhs: DataError) -> Bool {
    switch (lhs, rhs) {
    case (.noData, .noData):
      return true
    case let (.customError(a), .customError(b)):
      return a == b
    default:
      return false
    }
  }
}
