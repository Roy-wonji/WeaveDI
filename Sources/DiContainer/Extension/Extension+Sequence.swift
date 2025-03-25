//
//  Extension+Sequence.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/25/25.
//

import Foundation

public extension Sequence {
  func asyncForEach(_ body: (Element) async throws -> Void) async rethrows {
    for element in self {
      try await body(element)
    }
  }
}
