//
//  SendableHelpers.swift
//  DiContainer
//
//  Created by OpenAI on 2025-09-14.
//

import Foundation

/// A lightweight helper to intentionally box non-Sendable values
/// for use inside @Sendable closures. Use with caution and only if
/// you can guarantee thread-safety of the underlying value.
public struct UncheckedSendableBox<T>: @unchecked Sendable {
  public let value: T
  public init(_ value: T) { self.value = value }
}

/// Convenience function to create an UncheckedSendableBox
@inlinable
public func unsafeSendable<T>(_ value: T) -> UncheckedSendableBox<T> {
  UncheckedSendableBox(value)
}

