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
  public struct AnySendableBox: @unchecked Sendable {
    public let value: Any
    public init(_ v: Any) { self.value = v }
  }

  private var asyncFactories: [AnyTypeIdentifier: (@Sendable () async -> AnySendableBox)] = [:]

  public init() {}

  // MARK: Register

  /// Register an async factory for a type (transient resolution)
  public func register<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () async -> T
  ) {
    let key = AnyTypeIdentifier(type: type)
    asyncFactories[key] = { AnySendableBox(await factory()) }
  }


  // MARK: Resolve

  /// Resolve a type and return a sendable box
  public func resolveBox<T>(_ type: T.Type) async -> AnySendableBox? {
    let key = AnyTypeIdentifier(type: type)
    if let maker = asyncFactories[key] {
      let box = await maker()
      return box
    }
    return nil
  }


  // MARK: Maintenance

  /// Release a registration (factory)
  public func release<T>(_ type: T.Type) {
    let key = AnyTypeIdentifier(type: type)
    asyncFactories[key] = nil
  }

  /// Clear all registrations (test-only recommended)
  public func clearAll() {
    asyncFactories.removeAll()
  }
}
