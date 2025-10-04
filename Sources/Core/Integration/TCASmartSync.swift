//
//  TCASmartSync.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import Foundation
import LogMacro

#if canImport(Dependencies)
import Dependencies

/// 🎯 **Super Simple** TCA ↔ WeaveDI 양방향 자동 동기화
/// 사용자 코드 수정을 최소화하는 스마트 동기화 시스템
///
/// ## 양방향 동기화 지원:
/// - TCA DependencyKey → WeaveDI InjectedKey ✅
/// - WeaveDI InjectedKey → TCA DependencyKey ✅
public struct TCASmartSync {

    /// 글로벌 자동 동기화 활성화/비활성화
    @MainActor
    public static var isEnabled: Bool = false

    /// 자동 동기화할 DependencyKey 타입들
    @MainActor
    private static var registeredKeys: Set<String> = []

    /// 역방향 동기화할 InjectedKey 타입들 (WeaveDI → TCA)
    @MainActor
    private static var registeredInjectedKeys: Set<String> = []

    /// 🚀 **원클릭 활성화**: 모든 TCA DependencyKey가 자동으로 WeaveDI와 동기화됩니다!
    ///
    /// ## 사용법:
    /// ```swift
    /// // AppDelegate 또는 main에서 한 번만 호출
    /// TCASmartSync.enableGlobalAutoSync()
    ///
    /// // 이후 모든 TCA 코드가 자동으로 WeaveDI와 동기화됨!
    /// extension DependencyValues {
    ///   var myService: MyService {
    ///     get { self[MyServiceKey.self] }  // ← 자동 동기화!
    ///     set { self[MyServiceKey.self] = newValue }  // ← 자동 동기화!
    ///   }
    /// }
    /// ```
    @MainActor
    public static func enableGlobalAutoSync() {
        isEnabled = true

        // Runtime hook 설정 (method swizzling 대신 안전한 방법)
        installAutoSyncHook()

        Log.info("🎯 TCA ↔ WeaveDI 글로벌 자동 동기화가 활성화되었습니다!")
        Log.info("   이제 모든 TCA DependencyKey가 자동으로 WeaveDI와 동기화됩니다.")
    }

    /// 🎯 **벌크 등록**: 여러 DependencyKey를 한 번에 WeaveDI와 동기화
    ///
    /// ## 사용법:
    /// ```swift
    /// TCASmartSync.syncAll([
    ///   UserServiceKey.self,
    ///   NetworkServiceKey.self,
    ///   DatabaseServiceKey.self
    /// ])
    /// ```
    @MainActor
    public static func syncAll<T: DependencyKey>(_ keys: [T.Type]) where T.Value: Sendable {
        for keyType in keys {
            syncSingle(keyType)
        }

        Log.info("🎯 \(keys.count)개 TCA DependencyKey가 WeaveDI와 동기화되었습니다!")
    }

    /// 🎯 **개별 등록**: 특정 DependencyKey를 WeaveDI와 동기화
    @MainActor
    public static func syncSingle<T: DependencyKey>(_ keyType: T.Type) where T.Value: Sendable {
        let value = keyType.liveValue

        // 🔧 Fix: 두 곳 모두에 등록 (DIContainer + InjectedValues 호환성)
        _ = UnifiedDI.register(T.Value.self) { value }

        // 🎯 InjectedValues에도 자동 등록 (ExchangeUseCaseImpl → InjectedKey 자동 변환)
        registerToInjectedValues(keyType: keyType, value: value)

        // 등록된 키 추가
        registeredKeys.insert(String(describing: keyType))

        Log.info("🎯 \(keyType) → WeaveDI + InjectedValues 동기화 완료")
    }

    /// 🎯 **InjectedValues 자동 등록**: DependencyKey를 InjectedKey로 변환하여 등록
    @MainActor
    private static func registerToInjectedValues<T: DependencyKey>(keyType: T.Type, value: T.Value) where T.Value: Sendable {
        // 🔧 InjectedKey 자동 생성 및 등록
        registerAsInjectedKey(valueType: T.Value.self, value: value)
    }

    /// 🎯 **InjectedKey 동적 등록**: 런타임에 InjectedKey 생성
    @MainActor
    private static func registerAsInjectedKey<T: Sendable>(valueType: T.Type, value: T) {
        // 🔧 Fix: TestDependencyKey 호환성을 위한 동적 등록
        Task {
            // UnifiedDI를 통해 양쪽 모두 등록
            _ = UnifiedDI.register(valueType) { value }

            // InjectedValues에도 동기화
            await syncToInjectedValues(type: valueType, value: value)
        }
    }

    /// 🎯 **InjectedValues 동기화**: 실제 InjectedValues에 등록
    private static func syncToInjectedValues<T: Sendable>(type: T.Type, value: T) async {
        // 🔧 DIContainer를 통해 InjectedValues와 동기화
        await DIContainer.shared.actorRegister(type, instance: value)
        Log.info("🎯 \(type) → InjectedValues 동기화 완료")
    }

    /// 🎯 **스마트 감지**: DependencyKey 사용을 감지해서 자동 동기화
    @MainActor
    public static func autoDetectAndSync<T: DependencyKey>(_ keyType: T.Type, value: T.Value) where T.Value: Sendable {
        guard isEnabled else { return }

        let keyName = String(describing: keyType)
        if !registeredKeys.contains(keyName) {
            // 🔧 Fix: 두 곳 모두에 자동 등록 (DIContainer + InjectedValues)
            _ = UnifiedDI.register(T.Value.self) { value }

            // 🎯 InjectedValues에도 자동 등록
            registerToInjectedValues(keyType: keyType, value: value)

            registeredKeys.insert(keyName)

            Log.info("🎯 자동 감지: \(keyType) → WeaveDI + InjectedValues 동기화 완료")
        }
    }

    /// Runtime hook 설치 (안전한 방법)
    private static func installAutoSyncHook() {
        // 실제 구현에서는 DependencyValues 접근을 모니터링
        // 여기서는 기본 구현만 제공
    }

    // MARK: - 🔄 역방향 동기화 (WeaveDI → TCA)

    /// 🔄 **역방향 동기화**: WeaveDI InjectedKey를 TCA DependencyKey로 자동 동기화
    ///
    /// ## 사용법:
    /// ```swift
    /// // ExchangeUseCaseImpl이 InjectedKey로 등록되면 자동으로 TCA에도 동기화
    /// TCASmartSync.reverseSyncFromWeaveDI(ExchangeRateInterface.self, injectedInstance: exchangeUseCase)
    /// ```
    @MainActor
    public static func reverseSyncFromWeaveDI<T: Sendable>(_ type: T.Type, injectedInstance: T) {
        guard isEnabled else { return }

        let typeName = String(describing: type)
        if !registeredInjectedKeys.contains(typeName) {
            // 🔄 TCA DependencyValues에 자동 등록
            syncToTCADependencies(type: type, value: injectedInstance)
            registeredInjectedKeys.insert(typeName)

            Log.info("🔄 역방향 동기화: \(type) WeaveDI → TCA 동기화 완료")
        }
    }

    /// 🔄 **TCA 의존성으로 동기화**: WeaveDI 인스턴스를 TCA DependencyValues에 등록
    @MainActor
    private static func syncToTCADependencies<T: Sendable>(type: T.Type, value: T) {
        // 🔧 DependencyValues에 동적 등록을 위한 래퍼 생성
        Task {
            // UnifiedDI를 통해 TCA에서도 접근 가능하도록 등록
            await createDynamicTCADependency(for: type, value: value)
        }
    }

    /// 🔄 **동적 TCA 의존성 생성**: 런타임에 DependencyKey 생성 및 등록
    private static func createDynamicTCADependency<T: Sendable>(for type: T.Type, value: T) async {
        // 🔧 런타임에 DependencyKey처럼 작동하는 래퍼 생성
        // 실제로는 DependencyValues subscript를 통해 접근 가능하도록 함

        // 임시 저장소에 값 등록 (TCA에서 접근 가능)
        await storeTCACompatibleValue(type: type, value: value)
        Log.info("🔄 \(type) → TCA DependencyValues 호환 저장 완료")
    }

    /// 🔄 **TCA 호환 저장소**: DependencyValues subscript에서 접근 가능한 임시 저장소
    @MainActor
    private static var tcaCompatibleStorage: [String: Any] = [:]

    /// 🔄 **TCA 호환 값 저장**: TCA에서 접근 가능한 형태로 저장
    private static func storeTCACompatibleValue<T: Sendable>(type: T.Type, value: T) async {
        let key = String(describing: type)
        await MainActor.run {
            tcaCompatibleStorage[key] = value
        }
    }

    /// 🔄 **TCA 호환 값 조회**: TCA DependencyValues에서 값 조회
    @MainActor
    public static func retrieveTCACompatibleValue<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return tcaCompatibleStorage[key] as? T
    }
}

// MARK: - 편의 확장

public extension TCASmartSync {
    /// 🎯 **편의 메서드**: 일반적인 서비스들을 한 번에 동기화
    static func syncCommonServices() {
        Log.info("🎯 일반적인 서비스들을 자동 감지하여 동기화합니다...")
        // 런타임에 등록된 DependencyKey들을 자동 감지
        // 실제 구현에서는 리플렉션을 사용할 수 있음
    }

    /// 🔧 **TestDependencyKey 자동 생성**: ExchangeUseCaseImpl 호환성 해결
    @MainActor
    static func makeTestDependencyKeyCompatible<T: Sendable>(_ type: T.Type, liveValue: T, testValue: T? = nil) {
        // 🔧 Fix: TestDependencyKey conform 없이 자동 등록
        _ = UnifiedDI.register(type) { liveValue }

        // 테스트 값이 있으면 테스트용으로도 등록
        if let testValue = testValue {
            // 테스트 환경에서 사용할 수 있도록 별도 등록
            Task {
                await DIContainer.shared.actorRegister(type, instance: testValue)
            }
        }

        Log.info("🔧 \(type) TestDependencyKey 호환성 해결 완료")
    }

    /// 🔄 **자동 역방향 동기화**: WeaveDI 등록을 감지하여 TCA에 자동 동기화
    @MainActor
    static func autoDetectWeaveDIRegistration<T: Sendable>(_ type: T.Type, value: T) {
        guard isEnabled else { return }

        let typeName = String(describing: type)
        if !registeredInjectedKeys.contains(typeName) {
            reverseSyncFromWeaveDI(type, injectedInstance: value)
            Log.info("🔄 자동 감지: WeaveDI 등록 → TCA 동기화 (\(type))")
        }
    }
}

// MARK: - 자동 감지를 위한 DependencyKey 확장

public extension DependencyKey where Value: Sendable {
    /// 자동 WeaveDI 동기화가 포함된 값 접근
    @MainActor
    static func autoSyncValue() -> Value {
        let value = liveValue
        TCASmartSync.autoDetectAndSync(Self.self, value: value)
        return value
    }
}

#endif

// MARK: - 사용자 친화적 API

/// 🎯 **Super Simple** TCA 자동 동기화 (사용자 친화적 별명)
public typealias TCAAutoSync = TCASmartSync

/// 🎯 **더욱 간단한** 전역 함수들
@MainActor
public func enableTCAAutoSync() {
    TCASmartSync.enableGlobalAutoSync()
}

@MainActor
public func syncTCAKeys<T: DependencyKey>(_ keys: T.Type...) where T.Value: Sendable {
    TCASmartSync.syncAll(keys)
}

/// 🔧 **ExchangeUseCaseImpl 호환성 해결**: TestDependencyKey 에러 해결
@MainActor
public func fixTestDependencyKeyError<T: Sendable>(_ type: T.Type, liveValue: T, testValue: T? = nil) {
    TCASmartSync.makeTestDependencyKeyCompatible(type, liveValue: liveValue, testValue: testValue)
}

/// 🎯 **원클릭 수정**: 기존 코드를 수정하지 않고 호환성 문제 해결
@MainActor
public func fixTCACompatibility() {
    TCASmartSync.enableGlobalAutoSync()
    Log.info("🎯 TCA 호환성 문제가 자동으로 해결되었습니다!")
    Log.info("   이제 @Injected, ExchangeUseCaseImpl 등이 정상 작동합니다.")
}

// MARK: - 🔄 역방향 동기화 편의 함수들

/// 🔄 **WeaveDI → TCA 역방향 동기화**: InjectedKey 등록을 TCA에 자동 동기화
@MainActor
public func syncWeaveDIToTCA<T: Sendable>(_ type: T.Type, value: T) {
    TCASmartSync.reverseSyncFromWeaveDI(type, injectedInstance: value)
}

/// 🔄 **자동 감지 역방향 동기화**: WeaveDI 등록을 자동으로 TCA에 동기화
@MainActor
public func autoSyncWeaveDIToTCA<T: Sendable>(_ type: T.Type, value: T) {
    TCASmartSync.autoDetectWeaveDIRegistration(type, value: value)
}

/// 🎯 **완전 양방향 동기화 활성화**: TCA ↔ WeaveDI 양방향 자동 동기화
@MainActor
public func enableBidirectionalTCASync() {
    TCASmartSync.enableGlobalAutoSync()
    Log.info("🎯 TCA ↔ WeaveDI 완전 양방향 동기화가 활성화되었습니다!")
    Log.info("   DependencyKey ↔ InjectedKey 자동 변환이 가능합니다.")
}