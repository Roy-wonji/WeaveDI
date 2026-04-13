//
//  DIContainer+SyncBridge.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//

import Foundation
import LogMacro

// MARK: - Synchronous bridging helpers

extension DIContainer {

  /// Invariant: `operations`는 생성된 TaskLocal 컨텍스트 내에서 단일 스레드로만 변이된다.
  final class RegistrationBatchContext: @unchecked Sendable {
    var operations: [@Sendable (UnifiedRegistry) async -> Void] = []
  }

  /// Wrapper to safely pass values between concurrent contexts
  final class SendableBox<T>: @unchecked Sendable {
    var value: T

    init(_ value: T) {
      self.value = value
    }
  }

  @TaskLocal static var batchContext: RegistrationBatchContext?

  /// Bridges an async operation to the existing synchronous API surface.
  @preconcurrency
  func blockingAwait<T: Sendable>(_ operation: @escaping @Sendable () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let resultBox = SendableBox<T?>(nil)

    let priority = Task.currentPriority
    Task(priority: priority) { @Sendable in
      resultBox.value = await operation()
      semaphore.signal()
    }

    semaphore.wait()
    return resultBox.value!
  }

  @discardableResult
  func registerInstanceSync<T>(_ type: T.Type, instance: T) -> T where T: Sendable {
    syncRegistry.registerInstance(type, instance: instance)
    if let batch = DIContainer.batchContext {
      batch.operations.append { registry in
        await registry.register(type, factory: { instance })
      }
    } else {
      scheduleActorUpdate {
        await $0.register(type, factory: { instance })
      }
    }
    postRegistrationHook(for: type)
    FastResolveCache.shared.set(type, value: instance)
    if WeaveDIConfiguration.enableVerboseLogging {
      DILogger.debug(channel: .registration, "Registered instance for \(String(describing: type))")
    }
    return instance
  }

  @discardableResult
  func registerFactorySync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
  ) -> @Sendable () -> Void where T: Sendable {
    syncRegistry.registerFactory(type, factory: factory)
    if let batch = DIContainer.batchContext {
      batch.operations.append { registry in
        await registry.register(type, factory: factory)
      }
    } else {
      scheduleActorUpdate {
        await $0.register(type, factory: factory)
      }
    }
    postRegistrationHook(for: type)
    FastResolveCache.shared.set(type, value: nil)
    if WeaveDIConfiguration.enableVerboseLogging {
      DILogger.debug(channel: .registration, "Registered factory for \(String(describing: type))")
    }

    let release: @Sendable () -> Void = { [weak self] in
      guard let self else { return }
      self.syncRegistry.release(type)
      self.scheduleActorRelease(type)
      if WeaveDIConfiguration.enableVerboseLogging {
        DILogger.debug("Released \(String(describing: type))")
      }
    }

    return release
  }

  func releaseSync<T>(_ type: T.Type) where T: Sendable {
    syncRegistry.release(type)
    scheduleActorRelease(type)
    FastResolveCache.shared.set(type, value: nil)
    if WeaveDIConfiguration.enableVerboseLogging {
      DILogger.debug("Released \(String(describing: type))")
    }
  }

  func postRegistrationHook<T>(for type: T.Type) where T: Sendable {
    if WeaveDIConfiguration.enableOptimizerTracking {
      OptimizationHooks.trackRegistration?(type)
    }

    if WeaveDIConfiguration.enableAutoMonitor {
      if let onModuleRegistered = OptimizationHooks.onModuleRegistered {
        Task { @Sendable in
          await onModuleRegistered(type)
        }
      }
    }
  }

  func scheduleActorUpdate(_ operation: @escaping @Sendable (UnifiedRegistry) async -> Void) {
    let taskID = UUID()
    let task = Task(priority: .utility) { @Sendable [weak self] in
      guard let self else { return }
      defer { self.removePendingTask(taskID) }
      await operation(self.unifiedRegistry)
    }
    addPendingTask(taskID, task: task)
  }

  func scheduleActorRelease<T>(_ type: T.Type) where T: Sendable {
    scheduleActorUpdate {
      await $0.release(type)
    }
  }

  func addPendingTask(_ id: UUID, task: Task<Void, Never>) {
    pendingTasksQueue.async(flags: .barrier) {
      self.pendingRegistryTasks[id] = task
    }
  }

  func removePendingTask(_ id: UUID) {
    pendingTasksQueue.async(flags: .barrier) {
      self.pendingRegistryTasks.removeValue(forKey: id)
    }
  }

  func snapshotPendingTasks() -> [Task<Void, Never>] {
    pendingTasksQueue.sync {
      Array(self.pendingRegistryTasks.values)
    }
  }

  func logResolutionMiss<T>(_ type: T.Type) where T: Sendable {
    let typeName = String(describing: type)
    switch DILogger.getCurrentLogLevel() {
    case .all:
      DILogger.info(channel: .registration, "⚠️ \(typeName) resolving returned nil")
      DILogger.info(channel: .registration, "💡 @AutoRegister를 사용하여 자동 등록을 활성화하세요")
      DILogger.error(channels: [.registration, .error], "No registered dependency found for \(typeName)")
    case .registration:
      DILogger.info(channel: .registration, "⚠️ \(typeName) resolving returned nil")
      DILogger.error(channels: [.registration, .error], "No registered dependency found for \(typeName)")
    case .optimization, .health:
      DILogger.error(channels: [.error], "No registered dependency found for \(typeName)")
    case .errorsOnly:
      DILogger.error(channels: [.error], "No registered dependency found for \(typeName)")
    case .off:
      return
    }

    OptimizationHooks.handleNilResolution?(type)
  }
}
