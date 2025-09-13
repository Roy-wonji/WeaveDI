//
//  DIAsync.swift
//  DiContainer
//
//  Created by OpenAI on 2025-09-14.
//

import Foundation

// MARK: - DIAsync (Concurrency-first API)

/// Concurrency-first DI API using actor-based registry.
/// Provides async register/resolve without relying on GCD.
public enum DIAsync {
  // Shared async registry
  private static let registry = AsyncTypeRegistry()

  // MARK: - Registration (Type)

  /// Register an async factory (transient)
  public static func register<T>(
    _ type: T.Type,
    factory: @Sendable @escaping () async -> T
  ) async {
    await registry.register(type, factory: factory)
  }

  /// Register a singleton instance
  public static func registerSingleton<T>(
    _ type: T.Type,
    instance: T
  ) async {
    // Box before crossing actor boundary to avoid sending non-Sendable across actor isolation
    let box = AsyncTypeRegistry.AnySendableBox(instance)
    await registry.registerInstanceBoxed(type, boxed: box)
    // Interop: also register into sync container for mixed usage
    DependencyContainer.live.register(T.self, instance: instance)
  }

  // MARK: - Registration (KeyPath convenience)

  /// Register via KeyPath and return the created instance (singleton semantics)
  @discardableResult
  public static func register<T>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    factory: @Sendable @escaping () async -> T
  ) async -> T {
    let instance = await factory()
    let box = AsyncTypeRegistry.AnySendableBox(instance)
    await registry.registerInstanceBoxed(T.self, boxed: box)
    // Interop with sync container
    DependencyContainer.live.register(T.self, instance: instance)
    return instance
  }

  // MARK: - Resolve

  /// Resolve an instance (async). Falls back to sync container if not found.
  public static func resolve<T>(_ type: T.Type) async -> T? {
    if let box = await registry.resolveBox(T.self) { return box.value as? T }
    // Fallback to sync registry for mixed mode
    return DependencyContainer.live.resolve(T.self)
  }
}
