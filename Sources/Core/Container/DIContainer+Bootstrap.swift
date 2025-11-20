//
//  DIContainer+Bootstrap.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//

import Foundation
import LogMacro

// MARK: - Bootstrap System

public extension DIContainer {

  /// 컨테이너를 부트스트랩합니다 (동기 등록)
  ///
  /// 앱 시작 시 의존성을 안전하게 초기화하기 위한 메서드입니다.
  /// 원자적으로 컨테이너를 교체하여 초기화 경합을 방지합니다.
  ///
  /// - Parameter configure: 의존성 등록 클로저
  static func bootstrap(_ configure: @Sendable (DIContainer) -> Void) async {
    let newContainer = DIContainer()
    configure(newContainer)
    Self.shared = newContainer
    DILogger.debug("Container bootstrapped (sync)")
  }

  /// 백그라운드 UnifiedRegistry 싱크 작업을 모두 기다립니다.
  /// 테스트나 진단 시점에서 사용하면, 동기 API 호출 직후에도
  /// UnifiedRegistry 상태가 최신임을 보장할 수 있습니다.
  func awaitPendingRegistryTasks() async {
    let tasks = snapshotPendingTasks()
    guard !tasks.isEmpty else { return }
    for task in tasks {
      _ = await task.value
    }
  }

  /// 전역 컨테이너의 백그라운드 싱크 작업을 모두 처리합니다.
  static func flushPendingRegistryTasks() async {
    await shared.awaitPendingRegistryTasks()
  }

  /// Registers multiple dependencies using a single UnifiedRegistry task to reduce overhead.
  func performBatchRegistration(_ block: @Sendable (DIContainer) -> Void) async {
    let context = RegistrationBatchContext()
    DIContainer.$batchContext.withValue(context) {
      block(self)
    }

    guard !context.operations.isEmpty else { return }

    let taskID = UUID()
    let task = Task(priority: .utility) { [weak self] in
      guard let self else { return }
      defer { self.removePendingTask(taskID) }
      for operation in context.operations {
        await operation(self.unifiedRegistry)
      }
    }

    addPendingTask(taskID, task: task)
    await task.value
  }

  /// Async overload for batch registration.
  func performBatchRegistration(_ block: @Sendable (DIContainer) async -> Void) async {
    let context = RegistrationBatchContext()
    await DIContainer.$batchContext.withValue(context) {
      await block(self)
    }

    guard !context.operations.isEmpty else { return }

    let taskID = UUID()
    let task = Task(priority: .utility) { [weak self] in
      guard let self else { return }
      defer { self.removePendingTask(taskID) }
      for operation in context.operations {
        await operation(self.unifiedRegistry)
      }
    }

    addPendingTask(taskID, task: task)
    await task.value
  }

  /// 컨테이너를 부트스트랩합니다 (비동기 등록)
  ///
  /// 비동기 초기화가 필요한 의존성(예: 데이터베이스, 원격 설정)이 있을 때 사용합니다.
  ///
  /// - Parameter configure: 비동기 의존성 등록 클로저
  @discardableResult
  static func bootstrapAsync(_ configure: @Sendable (DIContainer) async throws -> Void) async -> Bool {
    do {
      let startTime = CFAbsoluteTimeGetCurrent()
      DILogger.debug("Starting Container async bootstrap...")

      let newContainer = DIContainer()
      try await configure(newContainer)
      Self.shared = newContainer

      let duration = CFAbsoluteTimeGetCurrent() - startTime
      DILogger.debug("Container bootstrapped successfully in \(String(format: "%.3f", duration))s")
      return true
    } catch {
      DILogger.error("Container bootstrap failed: \(error)")
#if DEBUG
      fatalError("Container bootstrap failed: \(error)")
#else
      return false
#endif
    }
  }

  /// 별도의 Task 컨텍스트에서 비동기 부트스트랩을 수행하는 편의 메서드입니다
  static func bootstrapInTask(_ configure: @Sendable @escaping (DIContainer) async throws -> Void) {
    Task.detached(priority: .high) {
      let success = await bootstrapAsync(configure)
      if success {
        await MainActor.run { DILogger.debug("Container bootstrap completed in background task") }
      } else {
        await MainActor.run { DILogger.error("Container bootstrap failed in background task") }
      }
    }
  }

  /// 혼합 부트스트랩 (동기 + 비동기)
  ///
  /// - Parameters:
  ///   - sync: 즉시 필요한 의존성 등록
  ///   - async: 비동기 초기화가 필요한 의존성 등록
  @MainActor
  static func bootstrapMixed(
    sync: @Sendable (DIContainer) -> Void,
    async: @Sendable (DIContainer) async -> Void
  ) async {
    let newContainer = DIContainer()
    // 1) 동기 등록
    sync(newContainer)
    DILogger.debug(channel: .registration, "Core dependencies registered synchronously")
    // 2) 비동기 등록
    await async(newContainer)
    DILogger.debug(channel: .registration, "Extended dependencies registered asynchronously")

    Self.shared = newContainer
    DILogger.debug("Container bootstrapped with mixed dependencies")
  }

  /// 이미 부트스트랩되어 있지 않은 경우에만 실행합니다
  ///
  /// - Parameter configure: 의존성 등록 클로저
  /// - Returns: 부트스트랩이 수행되었는지 여부
  @discardableResult
  static func bootstrapIfNeeded(_ configure: @Sendable (DIContainer) -> Void) async -> Bool {
    // 간단한 체크: shared 인스턴스가 비어있으면 부트스트랩
    if shared.isEmpty {
      await bootstrap(configure)
      return true
    }
    DILogger.debug("Container bootstrap skipped - already initialized")
    return false
  }

  /// 이미 부트스트랩되어 있지 않은 경우에만 비동기 부트스트랩을 수행합니다
  @discardableResult
  static func bootstrapAsyncIfNeeded(_ configure: @Sendable (DIContainer) async throws -> Void) async -> Bool {
    if shared.isEmpty {
      return await bootstrapAsync(configure)
    } else {
      DILogger.debug("Container bootstrap skipped - already initialized")
      return false
    }
  }

  /// 런타임에 의존성을 업데이트합니다 (동기)
  ///
  /// - Parameter configure: 업데이트할 의존성 등록 클로저
  static func update(_ configure: @Sendable (DIContainer) -> Void) async {
    configure(shared)
    DILogger.debug("Container updated (sync)")
  }

  /// 런타임에 의존성을 업데이트합니다 (비동기)
  ///
  /// - Parameter configure: 비동기 업데이트 클로저
  static func updateAsync(_ configure: @Sendable (DIContainer) async -> Void) async {
    await configure(shared)
    DILogger.debug("Container updated (async)")
  }

  /// DI 컨테이너 접근 전, 부트스트랩이 완료되었는지를 보장합니다
  static func ensureBootstrapped(
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    precondition(
      isBootstrapped,
      "DI not bootstrapped. Call DIContainer.bootstrap(...) first.",
      file: file,
      line: line
    )
  }

  /// 테스트를 위해 컨테이너를 초기화합니다
  ///
  /// ⚠️ DEBUG 빌드에서만 사용 가능합니다.
  @MainActor
  static func resetForTesting() {
#if DEBUG
    Self.shared = DIContainer()
    DILogger.debug("Container reset for testing")
#else
    fatalError("resetForTesting() is only available in DEBUG builds")
#endif
  }

  /// 부트스트랩 상태를 확인합니다
  static var isBootstrapped: Bool {
    !shared.isEmpty
  }
}
