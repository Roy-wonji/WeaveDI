//
//  DIAsync.swift
//  DiContainer
//
//  Created by OpenAI on 2025-09-14.
//

import Foundation
import LogMacro

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


  // MARK: - Registration (KeyPath convenience)

  /// Register via KeyPath and return the created instance
  @discardableResult
  public static func register<T>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    factory: @Sendable @escaping () async -> T
  ) async -> T where T: Sendable {
    let instance = await factory()
    await registry.register(T.self, factory: { instance })
    // Interop with sync container
    DependencyContainer.live.register(T.self, instance: instance)
    return instance
  }

  /// Get or create via KeyPath-style registration (idempotent)
  @discardableResult
  public static func getOrCreate<T>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    factory: @Sendable @escaping () async -> T
  ) async -> T where T: Sendable {
    // Check if already registered
    if let existing = await resolve(T.self) {
      return existing
    }

    // Create and register new instance
    let instance = await factory()
    await register(T.self, factory: { instance })
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

  /// Resolve or return default
  public static func resolve<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
  ) async -> T {
    if let value: T = await resolve(type) { return value }
    return defaultValue()
  }

  /// Require resolve (fatalError on failure)
  public static func requireResolve<T>(_ type: T.Type) async -> T {
    if let value: T = await resolve(type) { return value }
    fatalError("Required dependency \(T.self) not found (DIAsync.requireResolve)")
  }

  // MARK: - Conditional Registration

  public static func registerIf<T>(
    _ type: T.Type,
    condition: Bool,
    factory: @Sendable @escaping () async -> T,
    fallback: @Sendable @escaping () async -> T
  ) async {
    if condition {
      await register(type, factory: factory)
    } else {
      await register(type, factory: fallback)
    }
  }

  @discardableResult
  public static func registerIf<T>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    condition: Bool,
    factory: @Sendable @escaping () async -> T,
    fallback: @Sendable @escaping () async -> T
  ) async -> T where T: Sendable {
    if condition { return await register(keyPath, factory: factory) }
    return await register(keyPath, factory: fallback)
  }

  // MARK: - Batch Registration (async)

  public static func registerMany(
    @DIAsyncRegistrationBuilder _ registrations: () -> [DIAsyncRegistration]
  ) async {
    let items = registrations()
    await withTaskGroup(of: Void.self) { group in
      for item in items {
        group.addTask { @Sendable in await item.register() }
      }
      await group.waitForAll()
    }
  }

  // MARK: - Introspection

  /// Check if a type is registered in async or sync registry
  public static func isRegistered<T>(_ type: T.Type) async -> Bool {
    if await registry.resolveBox(T.self) != nil { return true }
    return DependencyContainer.live.resolve(T.self) != nil
  }

  /// Check if a KeyPath-identified dependency is registered
  public static func isRegistered<T>(_ keyPath: KeyPath<DependencyContainer, T?>) async -> Bool {
    await isRegistered(T.self)
  }

  // MARK: - Management

  /// Release all async registrations (testing purpose)
  public static func releaseAll() async {
    await registry.clearAll()
  }
}

// MARK: - Async Registration Builder

@resultBuilder
public struct DIAsyncRegistrationBuilder {
  public static func buildBlock(_ components: DIAsyncRegistration...) -> [DIAsyncRegistration] {
    components
  }
}

public struct DIAsyncRegistration: Sendable {
  private let action: @Sendable () async -> Void

  public init<T>(_ type: T.Type, factory: @Sendable @escaping () async -> T) {
    self.action = { @Sendable in await DIAsync.register(type, factory: factory) }
  }


  public init<T>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    factory: @Sendable @escaping () async -> T
  ) {
    // Work around KeyPath not being Sendable - capture type instead
    let type = T.self
    self.action = { @Sendable in await DIAsync.register(type, factory: factory) }
  }

  fileprivate func register() async { await action() }
}
