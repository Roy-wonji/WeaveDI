//
//  AsyncTypeRegistry.swift
//  DiContainer
//
//  Created by OpenAI on 2025-09-14.
//

import Foundation
import LogMacro

// MARK: - AsyncTypeRegistry

/// Actor-based async registry for DIAsync.
/// Stores async factories without using GCD/locks.
public actor AsyncTypeRegistry {
  // Type-erased, sendable box to safely move values across concurrency domains
  /// Invariant: values inserted must conform to `Sendable`; enforced by the
  /// `where T: Sendable` constraint on the exposed APIs.
  public struct AnySendableBox: Sendable {
    public let value: any Sendable
    public init(_ v: any Sendable) { self.value = v }
  }

  private var asyncFactories: [AnyTypeIdentifier: (@Sendable () async -> AnySendableBox)] = [:]

  public init() {}

  // MARK: Register

  /// Register an async factory for a type (transient resolution)
  public func register<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () async -> T
  ) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    asyncFactories[key] = { AnySendableBox(await factory()) }
  }


  // MARK: Resolve

  /// Resolve a type and return a sendable box
  public func resolveBox<T>(_ type: T.Type) async -> AnySendableBox? where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    if let maker = asyncFactories[key] {
      let box = await maker()
      return box
    }
    return nil
  }


  // MARK: Maintenance

  /// Release a registration (factory)
  public func release<T>(_ type: T.Type) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    asyncFactories[key] = nil
  }

  /// Clear all registrations (test-only recommended)
  public func clearAll() {
    asyncFactories.removeAll()
  }
}
