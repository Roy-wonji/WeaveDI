//
//  DIAdvanced.swift
//  DiContainer
//
//  Created by Wonji Suh on 2024.
//  Copyright © 2024 Wonji Suh. All rights reserved.
//

import Foundation

// MARK: - Advanced DI Features

/// ## 개요
///
/// `DIAdvanced`는 Wonji Suh가 설계한 고급 의존성 주입 기능들을 제공합니다.
/// 일반적인 사용에서는 필요하지 않지만, 특수한 요구사항이 있을 때 사용할 수 있습니다.
///
/// ## 설계 철학
/// - **선택적 복잡성**: 필요할 때만 사용하는 고급 기능
/// - **명확한 분리**: 핵심 API와 분리하여 복잡도 최소화
/// - **실용적 접근**: 실제로 필요한 기능들만 제공
public enum DIAdvanced {

    // MARK: - Performance Features

    /// 성능 최적화 관련 기능들
    public enum Performance {

        /// 성능 추적과 함께 의존성을 해결합니다
        ///
        /// 자동 성능 최적화와 함께 의존성을 해결합니다.
        /// AutoDIOptimizer가 자동으로 사용 통계를 수집합니다.
        ///
        /// - Parameter type: 해결할 타입
        /// - Returns: 해결된 인스턴스 (없으면 nil)
        public static func resolveWithTracking<T>(_ type: T.Type) -> T? {
            AutoDIOptimizer.shared.trackResolution(type)
            return DependencyContainer.live.resolve(type)
        }

        /// 자주 사용되는 타입으로 표시하여 성능을 최적화합니다
        ///
        /// - Parameter type: 최적화할 타입
        @MainActor
        public static func markAsFrequentlyUsed<T>(_ type: T.Type) {
            // AutoDIOptimizer가 자동으로 처리하므로 별도 처리 불필요
            AutoDIOptimizer.shared.trackResolution(type)
        }

        /// 성능 최적화를 활성화합니다
        @MainActor
        public static func enableOptimization() {
            AutoDIOptimizer.shared.setOptimizationEnabled(true)
        }

        /// 현재 성능 통계를 반환합니다
        @MainActor
        public static func getStats() -> [String: Int] {
            return AutoDIOptimizer.shared.currentStats
        }
    }

    // MARK: - Batch Registration Features

    /// 일괄 등록 관련 기능들
    public enum Batch {

        /// 여러 의존성을 한번에 등록합니다
        ///
        /// - Parameter registrations: 등록할 의존성 목록
        public static func registerMany(@BatchRegistrationBuilder _ registrations: () -> [BatchRegistration]) {
            let items = registrations()
            for registration in items {
                registration.register()
            }
        }
    }

    // MARK: - Auto Detection Features (제거됨)

    /// 자동 의존성 감지 기능은 제거되었습니다.
    /// 대신 수동으로 의존성 그래프를 관리하거나 DependencyGraph를 사용하세요.
    @available(*, deprecated, message: "AutoDetection 기능이 제거되었습니다. DependencyGraph를 사용하세요.")
    public enum AutoDetection {
        /// 더 이상 지원되지 않습니다
        public static func enable() {
            // No-op: 기능이 제거됨
        }

        /// 더 이상 지원되지 않습니다
        public static func disable() {
            // No-op: 기능이 제거됨
        }
    }

    // MARK: - Scope Management Features

    /// 스코프 관리 관련 기능들
    public enum Scope {

        /// 스코프 기반 등록 (동기)
        @discardableResult
        public static func registerScoped<T>(
            _ type: T.Type,
            scope: ScopeKind,
            factory: @escaping @Sendable () -> T
        ) -> @Sendable () -> Void {
            Task.detached { @Sendable in
                await GlobalUnifiedRegistry.registerScoped(type, scope: scope, factory: factory)
            }
            return { }
        }

        /// 스코프 기반 등록 (비동기)
        public static func registerAsyncScoped<T>(
            _ type: T.Type,
            scope: ScopeKind,
            factory: @escaping @Sendable () async -> T
        ) {
            Task.detached { @Sendable in
                await GlobalUnifiedRegistry.registerAsyncScoped(type, scope: scope, factory: factory)
            }
        }

        /// 특정 스코프의 모든 인스턴스를 해제합니다
        @discardableResult
        public static func releaseScope(_ kind: ScopeKind, id: String) -> Int {
            let sem = DispatchSemaphore(value: 0)
            let box = IntBox()
            Task.detached { @Sendable in
                box.value = await GlobalUnifiedRegistry.releaseScope(kind: kind, id: id)
                sem.signal()
            }
            sem.wait()
            return box.value
        }

        /// 특정 타입의 스코프 인스턴스를 해제합니다
        @discardableResult
        public static func releaseScoped<T>(_ type: T.Type, kind: ScopeKind, id: String) -> Bool {
            let sem = DispatchSemaphore(value: 0)
            let box = BoolBox()
            Task.detached { @Sendable in
                box.value = await GlobalUnifiedRegistry.releaseScoped(type, kind: kind, id: id)
                sem.signal()
            }
            sem.wait()
            return box.value
        }
    }
}

// MARK: - Batch Registration Support

/// 일괄 등록을 위한 Result Builder
@resultBuilder
public struct BatchRegistrationBuilder {
    public static func buildBlock(_ components: BatchRegistration...) -> [BatchRegistration] {
        return components
    }

    public static func buildArray(_ components: [BatchRegistration]) -> [BatchRegistration] {
        return components
    }

    public static func buildOptional(_ component: BatchRegistration?) -> [BatchRegistration] {
        return component.map { [$0] } ?? []
    }

    public static func buildEither(first component: BatchRegistration) -> [BatchRegistration] {
        return [component]
    }

    public static func buildEither(second component: BatchRegistration) -> [BatchRegistration] {
        return [component]
    }
}

/// 일괄 등록을 위한 등록 아이템
public struct BatchRegistration {
    private let registerAction: () -> Void

    /// 팩토리 기반 등록
    public init<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) where T: Sendable {
        self.registerAction = {
            _ = DI.register(type, factory: factory)
        }
    }

    /// 기본값 포함 등록
    public init<T>(_ type: T.Type, default defaultValue: T) where T: Sendable {
        self.registerAction = {
            DependencyContainer.live.register(type, instance: defaultValue)
        }
    }

    /// 조건부 등록
    public init<T>(
        _ type: T.Type,
        condition: Bool,
        factory: @escaping @Sendable () -> T,
        fallback: @escaping @Sendable () -> T
    ) where T: Sendable {
        self.registerAction = {
            _ = DI.Conditional.registerIf(type, condition: condition, factory: factory, fallback: fallback)
        }
    }

    /// 등록 실행
    internal func register() {
        registerAction()
    }
}

// MARK: - Helper Classes

/// 정수값을 안전하게 전달하기 위한 박스
private final class IntBox: @unchecked Sendable {
    var value: Int = 0
    init() {}
}

/// 불린값을 안전하게 전달하기 위한 박스
private final class BoolBox: @unchecked Sendable {
    var value: Bool = false
    init() {}
}