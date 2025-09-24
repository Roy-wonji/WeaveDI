//
//  Extension+Data.swift
//  AppleStoreProductKiosk
//
//  Created by Wonji Suh  on 9/16/25.
//

import Foundation

/// Data 타입에 대한 JSON 디코딩 확장입니다.
extension Data {
  /// Data를 지정한 Decodable 타입으로 디코딩합니다.
  ///
  /// - Parameter type: 디코딩할 타입
  /// - Returns: 디코딩된 객체
  /// - Throws: 디코딩 실패 시 에러 발생
  func decoded<T: Decodable>(as type: T.Type) throws -> T {
    let decoder = JSONDecoder()
    return try decoder.decode(T.self, from: self)
  }
}
