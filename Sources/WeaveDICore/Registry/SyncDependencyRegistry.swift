//
//  SyncDependencyRegistry.swift
//  WeaveDI
//
//  Created by Codex on 2025.
//

import Foundation

/// Thread-safe synchronous registry that keeps local dependency snapshots.
///
/// Invariants:
/// - 모든 쓰기 작업은 `queue.syncBarrier` 경유로 직렬화된다.
/// - 저장된 엔트리는 `Sendable` 값 또는 `@Sendable` 팩토리여야 한다.
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
    queue.syncBarrier {
      storage[key] = .instance(instance)
    }
  }

  func registerFactory<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) where T: Sendable {
    let key = AnyTypeIdentifier(type: type)
    queue.syncBarrier {
      storage[key] = .factory(factory)
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
    queue.syncBarrier {
      storage.removeValue(forKey: key)
    }
  }

  func removeAll() {
    queue.syncBarrier {
      storage.removeAll()
    }
  }

  var isEmpty: Bool {
    queue.sync { storage.isEmpty }
  }
}

private extension DispatchQueue {
  @discardableResult
  func syncBarrier<Result>(execute work: () -> Result) -> Result {
    sync(flags: .barrier, execute: work)
  }
}
