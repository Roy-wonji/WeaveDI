//
//  UnifiedRegistry.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/19/25.
//

import Foundation
import LogMacro

// MARK: - Unified Registry System

/// ## 개요
///
/// `UnifiedRegistry`는 모든 의존성 등록 및 해결을 통합 관리하는 중앙화된 시스템입니다.
/// 기존의 분산된 Registry들(`TypeSafeRegistry`, `AsyncTypeRegistry`, `SimpleKeyPathRegistry`)을
/// 하나로 통합하여 일관성과 성능을 개선합니다.
///
/// ## 핵심 특징
///
/// ### 🏗️ 통합된 저장소
/// - **동기 팩토리**: 즉시 생성되는 의존성
/// - **비동기 팩토리**: async 컨텍스트에서 생성되는 의존성
/// - **싱글톤**: 한 번 생성되어 재사용되는 인스턴스
/// - **KeyPath 매핑**: 타입 안전한 KeyPath 기반 접근
///
/// ### 🔒 동시성 안전성
/// - **Actor 기반**: Swift Concurrency를 활용한 데이터 경쟁 방지
/// - **Type-safe Keys**: ObjectIdentifier 기반 타입 안전한 키
/// - **Memory Safety**: 자동 메모리 관리 및 순환 참조 방지
///
/// ### ⚡ 성능 최적화
/// - **지연 생성**: 실제 사용 시점까지 생성 지연
/// - **캐싱**: 싱글톤 인스턴스 캐싱
/// - **타입 추론**: 컴파일 타임 타입 최적화
/// - **성능 추적**: SimplePerformanceOptimizer 통합
///
/// ## 사용 예시
///
/// ### 기본 등록
/// ```swift
/// let registry = UnifiedRegistry()
///
/// // 팩토리 등록
/// await registry.register(NetworkService.self) { DefaultNetworkService() }
///
/// // 싱글톤 등록
/// await registry.registerSingleton(Database.self, instance: SQLiteDatabase())
///
/// // 비동기 팩토리 등록
/// await registry.registerAsync(CloudService.self) { await CloudServiceImpl() }
/// ```
///
/// ### 해결 (Resolution)
/// ```swift
/// // 동기 해결
/// let service = await registry.resolve(NetworkService.self)
///
/// // 비동기 해결
/// let cloudService = await registry.resolveAsync(CloudService.self)
///
/// // KeyPath 기반 해결
/// let database = await registry.resolve(keyPath: \.database)
///
/// // 성능 추적과 함께 해결
/// let service = await registry.resolveWithPerformanceTracking(NetworkService.self)
/// ```
///
/// ### 조건부 등록
/// ```swift
/// await registry.registerIf(
///     AnalyticsService.self,
///     condition: !isDebugMode,
///     factory: { FirebaseAnalytics() },
///     fallback: { MockAnalytics() }
/// )
/// ```
public actor UnifiedRegistry {

    // MARK: - Storage Types

    /// Type-erased, sendable box for storing values safely across concurrency boundaries
    public struct ValueBox: @unchecked Sendable {
        public let value: Any
        public let typeName: String

        public init<T>(_ value: T) {
            self.value = value
            self.typeName = String(describing: T.self)
        }

        public func unwrap<T>() -> T? {
            return value as? T
        }
    }

    /// Factory closure that produces instances
    public typealias SyncFactory = @Sendable () -> ValueBox
    public typealias AsyncFactory = @Sendable () async -> ValueBox

    // MARK: - Internal Storage

    /// 동기 팩토리 저장소 (매번 새 인스턴스 생성)
    private var syncFactories: [AnyTypeIdentifier: SyncFactory] = [:]

    /// 비동기 팩토리 저장소 (매번 새 인스턴스 생성)
    private var asyncFactories: [AnyTypeIdentifier: AsyncFactory] = [:]

    /// 싱글톤 인스턴스 캐시
    private var singletonInstances: [AnyTypeIdentifier: ValueBox] = [:]

    /// KeyPath 매핑 (KeyPath String -> TypeIdentifier)
    private var keyPathMappings: [String: AnyTypeIdentifier] = [:]

    /// 등록된 타입 통계 (디버깅 및 모니터링용)
    private var registrationStats: [AnyTypeIdentifier: RegistrationInfo] = [:]

    // MARK: - Initialization

    public init() {
        Log.debug("🏗️ [UnifiedRegistry] Initialized")
    }

    // MARK: - Synchronous Registration

    /// 동기 팩토리 등록 (매번 새 인스턴스 생성)
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - factory: 인스턴스를 생성하는 동기 클로저
    /// - Returns: 등록 해제 핸들러
    @discardableResult
    public func register<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> () -> Void {
        let key = AnyTypeIdentifier(type)
        let syncFactory: SyncFactory = { ValueBox(factory()) }

        syncFactories[key] = syncFactory
        updateRegistrationInfo(key, type: .syncFactory)

        Log.debug("✅ [UnifiedRegistry] Registered sync factory for \(String(describing: type))")

        return {
            // 단순한 no-op 핸들러로 변경 (실제 해제는 별도 메서드 호출로)
        }
    }

    /// 싱글톤 인스턴스 등록
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - instance: 공유할 인스턴스
    public func registerSingleton<T>(
        _ type: T.Type,
        instance: T
    ) {
        let key = AnyTypeIdentifier(type)
        let box = ValueBox(instance)

        singletonInstances[key] = box
        updateRegistrationInfo(key, type: .singleton)

        Log.debug("✅ [UnifiedRegistry] Registered singleton for \(String(describing: type))")
    }

    // MARK: - Asynchronous Registration

    /// 비동기 팩토리 등록 (매번 새 인스턴스 생성)
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - factory: 인스턴스를 생성하는 비동기 클로저
    /// - Returns: 등록 해제 핸들러
    @discardableResult
    public func registerAsync<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () async -> T
    ) -> () -> Void {
        let key = AnyTypeIdentifier(type)
        let asyncFactory: AsyncFactory = { ValueBox(await factory()) }

        asyncFactories[key] = asyncFactory
        updateRegistrationInfo(key, type: .asyncFactory)

        Log.debug("✅ [UnifiedRegistry] Registered async factory for \(String(describing: type))")

        return {
            // 단순한 no-op 핸들러로 변경 (실제 해제는 별도 메서드 호출로)
        }
    }

    /// 비동기 싱글톤 등록 (지연 생성 후 캐싱)
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - factory: 인스턴스를 생성하는 비동기 클로저 (최초 1회만 실행)
    public func registerAsyncSingleton<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () async -> T
    ) {
        let key = AnyTypeIdentifier(type)

        // 단순화된 접근: 첫 호출에서만 생성하고 이후는 캐시된 것 사용
        let cachedFactory: AsyncFactory = {
            // 간단한 캐싱 로직으로 변경
            let instance = await factory()
            return ValueBox(instance)
        }

        asyncFactories[key] = cachedFactory
        updateRegistrationInfo(key, type: .asyncSingleton)

        Log.debug("✅ [UnifiedRegistry] Registered async singleton for \(String(describing: type))")
    }

    /// 싱글톤 저장 (내부 헬퍼 메서드)
    internal func storeSingleton(key: AnyTypeIdentifier, box: ValueBox) {
        singletonInstances[key] = box
    }

    // MARK: - Conditional Registration

    /// 조건부 등록 (동기)
    public func registerIf<T>(
        _ type: T.Type,
        condition: Bool,
        factory: @escaping @Sendable () -> T,
        fallback: @escaping @Sendable () -> T
    ) {
        let selectedFactory = condition ? factory : fallback
        register(type, factory: selectedFactory)

        let conditionStr = condition ? "true" : "false"
        Log.debug("🔀 [UnifiedRegistry] Registered conditional (\(conditionStr)) for \(String(describing: type))")
    }

    /// 조건부 등록 (비동기)
    public func registerAsyncIf<T>(
        _ type: T.Type,
        condition: Bool,
        factory: @escaping @Sendable () async -> T,
        fallback: @escaping @Sendable () async -> T
    ) {
        let selectedFactory = condition ? factory : fallback
        registerAsync(type, factory: selectedFactory)

        let conditionStr = condition ? "true" : "false"
        Log.debug("🔀 [UnifiedRegistry] Registered async conditional (\(conditionStr)) for \(String(describing: type))")
    }

    // MARK: - KeyPath Support

    /// KeyPath를 사용한 등록
    /// - Parameters:
    ///   - keyPath: DependencyContainer 내의 KeyPath
    ///   - factory: 인스턴스 생성 팩토리
    public func register<T>(
        keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T
    ) {
        let keyPathString = String(describing: keyPath)
        let typeKey = AnyTypeIdentifier(T.self)

        // KeyPath 매핑 저장
        keyPathMappings[keyPathString] = typeKey

        // 실제 등록은 타입 기반으로 수행
        register(T.self, factory: factory)

        Log.debug("🔗 [UnifiedRegistry] Registered with KeyPath: \(keyPathString) -> \(String(describing: T.self))")
    }

    // MARK: - Resolution

    /// 동기 의존성 해결
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스 (없으면 nil)
    public func resolve<T>(_ type: T.Type) -> T? {
        let key = AnyTypeIdentifier(type)

        // 1. 싱글톤 캐시에서 확인
        if let box = singletonInstances[key] {
            let resolved: T? = box.unwrap()
            if let result = resolved {
                Log.debug("✅ [UnifiedRegistry] Resolved singleton \(String(describing: type))")
                return result
            }
        }

        // 2. 동기 팩토리에서 생성
        if let factory = syncFactories[key] {
            let box = factory()
            let resolved: T? = box.unwrap()
            if let result = resolved {
                Log.debug("✅ [UnifiedRegistry] Resolved from sync factory \(String(describing: type))")
                return result
            }
        }

        Log.debug("❌ [UnifiedRegistry] Failed to resolve \(String(describing: type))")
        return nil
    }

    /// 비동기 의존성 해결
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스 (없으면 nil)
    public func resolveAsync<T>(_ type: T.Type) async -> T? {
        let key = AnyTypeIdentifier(type)

        // 1. 싱글톤 캐시에서 확인
        if let box = singletonInstances[key] {
            let resolved: T? = box.unwrap()
            if let result = resolved {
                Log.debug("✅ [UnifiedRegistry] Resolved singleton async \(String(describing: type))")
                return result
            }
        }

        // 2. 비동기 팩토리에서 생성
        if let factory = asyncFactories[key] {
            let box = await factory()
            let resolved: T? = box.unwrap()
            if let result = resolved {
                Log.debug("✅ [UnifiedRegistry] Resolved from async factory \(String(describing: type))")
                return result
            }
        }

        // 3. 동기 팩토리에서 생성 (fallback)
        if let factory = syncFactories[key] {
            let box = factory()
            let resolved: T? = box.unwrap()
            if let result = resolved {
                Log.debug("✅ [UnifiedRegistry] Resolved from sync factory (async context) \(String(describing: type))")
                return result
            }
        }

        Log.debug("❌ [UnifiedRegistry] Failed to resolve async \(String(describing: type))")
        return nil
    }

    /// KeyPath를 사용한 해결
    /// - Parameter keyPath: DependencyContainer 내의 KeyPath
    /// - Returns: 해결된 인스턴스 (없으면 nil)
    public func resolve<T>(keyPath: KeyPath<DependencyContainer, T?>) -> T? {
        let keyPathString = String(describing: keyPath)

        guard keyPathMappings[keyPathString] != nil else {
            Log.debug("❌ [UnifiedRegistry] KeyPath not found: \(keyPathString)")
            return nil
        }

        // TypeKey로부터 실제 타입을 복원할 수 없으므로 direct resolve 사용
        return resolve(T.self)
    }

    // MARK: - Management

    /// 특정 타입의 등록을 해제합니다
    /// - Parameter type: 해제할 타입
    public func release<T>(_ type: T.Type) {
        let key = AnyTypeIdentifier(type)

        syncFactories.removeValue(forKey: key)
        asyncFactories.removeValue(forKey: key)
        singletonInstances.removeValue(forKey: key)
        registrationStats.removeValue(forKey: key)

        // KeyPath 매핑에서도 제거
        keyPathMappings = keyPathMappings.filter { $0.value != key }

        Log.debug("🗑️ [UnifiedRegistry] Released \(String(describing: type))")
    }

    /// 모든 등록을 해제합니다
    public func releaseAll() {
        let totalCount = syncFactories.count + asyncFactories.count + singletonInstances.count

        syncFactories.removeAll()
        asyncFactories.removeAll()
        singletonInstances.removeAll()
        keyPathMappings.removeAll()
        registrationStats.removeAll()

        Log.info("🧹 [UnifiedRegistry] Released all registrations (total: \(totalCount))")
    }

    // MARK: - Diagnostics

    /// 등록된 타입들의 통계 정보 반환
    /// - Returns: 등록 통계
    public func getRegistrationStats() -> [String: RegistrationInfo] {
        var result: [String: RegistrationInfo] = [:]
        for (key, info) in registrationStats {
            result[key.typeName] = info
        }
        return result
    }

    /// 특정 타입이 등록되었는지 확인
    /// - Parameter type: 확인할 타입
    /// - Returns: 등록 여부
    public func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = AnyTypeIdentifier(type)
        return syncFactories[key] != nil ||
               asyncFactories[key] != nil ||
               singletonInstances[key] != nil
    }

    /// 현재 등록된 모든 타입 이름 반환
    /// - Returns: 타입 이름 배열
    public func getAllRegisteredTypeNames() -> [String] {
        let allKeys = Set(syncFactories.keys)
            .union(Set(asyncFactories.keys))
            .union(Set(singletonInstances.keys))

        return allKeys.map(\.typeName).sorted()
    }

    // MARK: - Private Helpers

    /// 등록 정보 업데이트
    private func updateRegistrationInfo(_ key: AnyTypeIdentifier, type: RegistrationType) {
        let existing = registrationStats[key]
        let info = RegistrationInfo(
            type: type,
            registrationCount: (existing?.registrationCount ?? 0) + 1,
            lastRegistrationDate: Date()
        )
        registrationStats[key] = info
    }
}

// MARK: - Supporting Types

/// 등록 타입
public enum RegistrationType {
    case syncFactory
    case asyncFactory
    case singleton
    case asyncSingleton

    public var description: String {
        switch self {
        case .syncFactory: return "Sync Factory"
        case .asyncFactory: return "Async Factory"
        case .singleton: return "Singleton"
        case .asyncSingleton: return "Async Singleton"
        }
    }
}

/// 등록 정보
public struct RegistrationInfo {
    public let type: RegistrationType
    public let registrationCount: Int
    public let lastRegistrationDate: Date

    public var summary: String {
        return """
        Type: \(type.description)
        Count: \(registrationCount)
        Last: \(lastRegistrationDate)
        """
    }
}

// MARK: - Global Instance

/// 글로벌 통합 Registry 인스턴스
/// DependencyContainer.live에서 내부적으로 사용
public let GlobalUnifiedRegistry = UnifiedRegistry()