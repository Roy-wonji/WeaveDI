//
//  DependencyContainerBootstrap.swift
//  DiContainer
//
//  Created by 서원지 on 6/8/24.
//

import Foundation
import LogMacro

// MARK: - Bootstrap APIs

public extension DependencyContainer {

    // MARK: - Sync Bootstrap

    /// 앱 시작 시 1회, **동기 의존성**을 등록합니다.
    ///
    /// 부트스트랩이 아직 수행되지 않았다면 새 컨테이너를 생성해 `configure`로 동기 등록을 수행하고,
    /// 성공 시 ``live`` 와 ``didBootstrap`` 를 갱신합니다. 이미 부트스트랩된 경우 동작을 스킵합니다.
    static func bootstrap(
        _ configure: @Sendable (DependencyContainer) -> Void
    ) async {
        do {
            let result = try await coordinator.bootstrapIfNotAlready(configure)
            if result.success {
                self.live = result.container
                // authoritative state is managed by coordinator
                _ = await coordinator.isBootstrapped() // touch to ensure actor initialized
                await coordinator.setBootstrapped(true)
                Log.info("DependencyContainer bootstrapped synchronously")
            } else {
                Log.error("DependencyContainer is already bootstrapped")
            }
        } catch {
            Log.error("DependencyContainer bootstrap failed: \(error)")
            #if DEBUG
            fatalError("DependencyContainer bootstrap failed: \(error)")
            #endif
        }
    }

    // MARK: - Async Bootstrap

    /// 앱 시작 시 1회, **비동기 의존성**까지 포함하여 등록합니다.
    @discardableResult
    static func bootstrapAsync(
        _ configure: @Sendable (DependencyContainer) async throws -> Void
    ) async -> Bool {
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            Log.info("Starting DependencyContainer async bootstrap...")

            let result = try await coordinator.asyncBootstrapIfNotAlready(configure)

            if result.success {
                self.live = result.container
                await coordinator.setBootstrapped(true)
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                Log.info("DependencyContainer bootstrapped successfully in \(String(format: "%.3f", duration))s")
                return true
            } else {
                Log.error("DependencyContainer is already bootstrapped")
                return false
            }
        } catch {
            Log.error("DependencyContainer bootstrap failed: \(error)")
            #if DEBUG
            fatalError("DependencyContainer bootstrap failed: \(error)")
            #else
            return false
            #endif
        }
    }

    /// 별도의 `Task` 컨텍스트에서 **비동기 부트스트랩**을 수행하는 편의 메서드입니다.
    static func bootstrapInTask(
        _ configure: @Sendable @escaping (DependencyContainer) async throws -> Void
    ) {
        Task.detached(priority: .high) {
            let success = await bootstrapAsync(configure)
            if success {
                await MainActor.run { Log.info("DependencyContainer bootstrap completed in background task") }
            } else {
                await MainActor.run { Log.error("DependencyContainer bootstrap failed in background task") }
            }
        }
    }

    /// 이미 부트스트랩되어 있지 **않은 경우에만** 비동기 부트스트랩을 수행합니다.
    @discardableResult
    static func bootstrapIfNeeded(
        _ configure: @Sendable (DependencyContainer) async throws -> Void
    ) async -> Bool {
        let needsBootstrap = !(await coordinator.isBootstrapped())
        if needsBootstrap {
            return await bootstrapAsync(configure)
        } else {
            Log.debug("DependencyContainer bootstrap skipped - already initialized")
            return false
        }
    }

    /// 앱 시작 시 **동기 → 비동기** 순서로 의존성을 등록합니다.
    @MainActor
    static func bootstrapMixed(
        sync syncConfigure: @Sendable (DependencyContainer) -> Void,
        async asyncConfigure: @Sendable  (DependencyContainer) async -> Void
    ) async {
        let wasBootstrapped = await coordinator.isBootstrapped()
        guard !wasBootstrapped else {
            Log.error("DependencyContainer is already bootstrapped")
            return
        }

        do {
            let result = try await coordinator.asyncBootstrapIfNotAlready { container in
                // 1) 동기 등록
                syncConfigure(container)
                Log.debug("Core dependencies registered synchronously")
                // 2) 비동기 등록
                await asyncConfigure(container)
                Log.debug("Extended dependencies registered asynchronously")
            }

            if result.success {
                self.live = result.container
                await coordinator.setBootstrapped(true)
                Log.info("DependencyContainer bootstrapped with mixed dependencies")
            }
        } catch {
            Log.error("DependencyContainer mixed bootstrap failed: \(error)")
            #if DEBUG
            fatalError("DependencyContainer mixed bootstrap failed: \(error)")
            #endif
        }
    }

    // MARK: - Update APIs

    /// 실행 중 **동기**로 컨테이너를 갱신(교체/추가)합니다.
    static func update(
        _ mutate: (DependencyContainer) -> Void
    ) async {
        await ensureBootstrapped()
        mutate(self.live)
        Log.debug("DependencyContainer updated synchronously")
    }

    /// 실행 중 **비동기**로 컨테이너를 갱신(교체/추가)합니다.
    static func updateAsync(
        _ mutate: (DependencyContainer) async -> Void
    ) async {
        await ensureBootstrapped()
        await mutate(self.live)
        Log.debug("DependencyContainer updated asynchronously")
    }

    // MARK: - Utilities

    /// DI 컨테이너 접근 전, **부트스트랩이 완료되었는지**를 보장합니다.
    static func ensureBootstrapped(
        file: StaticString = #fileID,
        line: UInt = #line
    ) async {
        let isBootstrapped = await coordinator.isBootstrapped()
        precondition(
            isBootstrapped,
            "DI not bootstrapped. Call DependencyContainer.bootstrap(...) first.",
            file: file,
            line: line
        )
    }

    /// 현재 **부트스트랩 여부**를 나타냅니다.
    static var isBootstrapped: Bool {
        get async { await coordinator.isBootstrapped() }
    }

    /// **테스트 전용**: 컨테이너 상태를 리셋합니다. (`DEBUG` 빌드에서만 동작)
    static func resetForTesting() async {
        #if DEBUG
        await coordinator.resetForTesting()
        live = DependencyContainer()
        Log.error("DependencyContainer reset for testing")
        #else
        assertionFailure("resetForTesting() should only be called in DEBUG builds")
        #endif
    }
}