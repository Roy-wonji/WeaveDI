//
//  AsyncTypeRegistry.swift
//  DiContainer
//
//  Created by OpenAI on 2025-09-14.
//

import Foundation

// MARK: - AsyncTypeRegistry

/// Actor-based async registry for DIAsync.
/// Stores async factories and singleton instances without using GCD/locks.
public actor AsyncTypeRegistry {
  // Type-erased, sendable box to safely move values across concurrency domains
  public struct AnySendableBox: @unchecked Sendable { public let value: Any; public init(_ v: Any) { self.value = v } }
  // MARK: Storage

  private var asyncFactories: [AnyTypeIdentifier: (@Sendable () async -> AnySendableBox)] = [:]
  private var singletons: [AnyTypeIdentifier: AnySendableBox] = [:]

  public init() {}

  // MARK: Register

  /// Register an async factory for a type (transient resolution)
  public func register<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () async -> T
  ) {
    let key = AnyTypeIdentifier(type)
    asyncFactories[key] = { AnySendableBox(await factory()) }
  }

  /// Register a singleton instance for a type
  public func registerInstance<T>(
    _ type: T.Type,
    instance: T
  ) {
    let key = AnyTypeIdentifier(type)
    singletons[key] = AnySendableBox(instance)
  }

  /// Register a pre-boxed singleton instance (avoid sending non-Sendable across boundary)
  public func registerInstanceBoxed<T>(
    _ type: T.Type,
    boxed: AnySendableBox
  ) {
    let key = AnyTypeIdentifier(type)
    singletons[key] = boxed
  }

  // MARK: Resolve

  /// Resolve a type and return a sendable box
  public func resolveBox<T>(_ type: T.Type) async -> AnySendableBox? {
    let key = AnyTypeIdentifier(type)
    if let box = singletons[key] { return box }
    if let maker = asyncFactories[key] {
      let box = await maker()
      return box
    }
    return nil
  }

  /// Get an existing singleton box, or create/store one using the provided factory
  public func getOrCreateBox<T>(
    _ type: T.Type,
    orMake make: @Sendable () async -> AnySendableBox
  ) async -> AnySendableBox {
    let key = AnyTypeIdentifier(type)
    if let box = singletons[key] { return box }
    let newBox = await make()
    singletons[key] = newBox
    return newBox
  }

  // MARK: Maintenance

  /// Release a registration (singleton and factory)
  public func release<T>(_ type: T.Type) {
    let key = AnyTypeIdentifier(type)
    singletons[key] = nil
    asyncFactories[key] = nil
  }

  /// Clear all registrations (test-only recommended)
  public func clearAll() {
    singletons.removeAll()
    asyncFactories.removeAll()
  }
}
