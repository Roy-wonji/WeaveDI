//
//  SyncDependencyRegistry.swift
//  WeaveDI
//
//  Created by Codex on 2025.
//

import Foundation

/// Thread-safe synchronous registry that keeps local dependency snapshots.
///
/// This registry backs the synchronous DI APIs so they no longer need to hop
/// to the actor-backed `UnifiedRegistry`. Each `DIContainer` owns an instance
/// and mirrors writes to the async registry in the background.
final class SyncDependencyRegistry: @unchecked Sendable {

  private enum Entry {
    case instance(any Sendable)
    case factory(@Sendable () -> any Sendable)
  }

  private let queue = DispatchQueue(label: "com.weaveDI.syncRegistry", attributes: .concurrent)
  private var storage: [AnyTypeIdentifier: Entry] = [:]

  // MARK: - Registration

  func registerInstance<T>(_ type: T.Type, instance: T) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    queue.async(flags: .barrier) { [weak self] in
      guard let self else { return }
      self.storage[key] = .instance(instance)
    }
  }

  func registerFactory<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    queue.async(flags: .barrier) { [weak self] in
      guard let self else { return }
      self.storage[key] = .factory(factory)
    }
  }

  // MARK: - Resolution

  func resolve<T>(_ type: T.Type) -> T? where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    return queue.sync {
      guard let entry = storage[key] else { return nil }
      switch entry {
      case .instance(let value):
        return value as? T
      case .factory(let factory):
        return factory() as? T
      }
    }
  }

  // MARK: - Release

  func release<T>(_ type: T.Type) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    queue.async(flags: .barrier) { [weak self] in
      guard let self else { return }
      self.storage.removeValue(forKey: key)
    }
  }

  func removeAll() {
    queue.async(flags: .barrier) { [weak self] in
      guard let self else { return }
      self.storage.removeAll()
    }
  }
}
