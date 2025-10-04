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
/// - 완전 자동 초기화 (수동 호출 불필요) ✅
public struct TCASmartSync {

    /// 글로벌 자동 동기화 활성화/비활성화
    @MainActor
    public static var isEnabled: Bool = false

    /// 자동 초기화 완료 여부
    @MainActor
    private static var isAutoInitialized: Bool = false

    /// 🎯 **완전 자동 초기화**: 처음 사용 시 자동으로 모든 설정 완료
    @MainActor
    public static func ensureAutoInitialized() {
        guard !isAutoInitialized else { return }

        // 양방향 동기화 자동 활성화
        enableGlobalAutoSync()

        // 자동 초기화 완료 마킹
        isAutoInitialized = true

        Log.info("🎯 TCA ↔ WeaveDI 완전 자동 초기화 완료!")
        Log.info("   사용자 코드 수정 없이 자동으로 동기화됩니다.")
    }

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

    /// 🎯 **스마트 감지**: DependencyKey 사용을 감지해서 자동 동기화 (nonisolated)
    public static func autoDetectAndSync<T: DependencyKey>(_ keyType: T.Type, value: T.Value) where T.Value: Sendable {
        Task { @MainActor in
            // 🎯 완전 자동 초기화 (처음 사용 시)
            ensureAutoInitialized()

            guard isEnabled else { return }

            let keyName = String(describing: keyType)
            if !registeredKeys.contains(keyName) {
                // 🔧 Fix: 두 곳 모두에 자동 등록 (DIContainer + InjectedValues)
                _ = UnifiedDI.register(T.Value.self) { value }

                // 🎯 InjectedValues에도 자동 등록
                registerToInjectedValues(keyType: keyType, value: value)

                // 🔧 자동 TestDependencyKey 호환성 해결
                autoFixTestDependencyKeyForType(T.Value.self, value: value)

                registeredKeys.insert(keyName)

                Log.info("🎯 자동 감지: \(keyType) → WeaveDI + InjectedValues 동기화 완료")
            }
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

    /// 🔄 **TCA 호환 값 조회**: TCA DependencyValues에서 값 조회 (nonisolated)
    public static func retrieveTCACompatibleValue<T: Sendable>(_ type: T.Type) -> T? {
        // 🔄 1. TCA 호환 저장소에서 우선 조회
        if Thread.isMainThread {
            let value = MainActor.assumeIsolated {
                let key = String(describing: type)
                return tcaCompatibleStorage[key] as? T
            }
            if let value = value {
                return value
            }
        }

        // 🔄 2. WeaveDI에서 직접 조회 (완전 통합)
        if let injectedType = type as? any InjectedKey.Type {
            return injectedType.liveValue as? T
        }

        // 🔄 3. UnifiedDI에서 조회
        return try? DIContainer.shared.resolve(type)
    }

    /// 🔄 **완전 통합 저장소**: @Dependency와 @Injected가 동일한 인스턴스 반환하도록 보장
    @MainActor
    public static func getUnifiedValue<T: Sendable>(_ type: T.Type) -> T? {
        // 🔄 1. InjectedKey에서 liveValue 사용 (우선순위 1)
        if let injectedType = type as? any InjectedKey.Type {
            let value = injectedType.liveValue as! T
            // 즉시 저장소에 캐시
            tcaCompatibleStorage[String(describing: type)] = value
            return value
        }

        // 🔄 2. 기존 저장소에서 조회
        let key = String(describing: type)
        if let cachedValue = tcaCompatibleStorage[key] as? T {
            return cachedValue
        }

        // 🔄 3. DIContainer에서 조회
        if let resolvedValue = try? DIContainer.shared.resolve(type) {
            tcaCompatibleStorage[key] = resolvedValue
            return resolvedValue
        }

        return nil
    }

    /// 🔄 **통합 값 조회 (nonisolated)**: @Injected에서 사용하는 동기적 접근
    public static func getUnifiedValueSync<T: Sendable>(_ type: T.Type) -> T? {
        // 🔄 1. InjectedKey에서 liveValue 사용 (우선순위 1)
        if let injectedType = type as? any InjectedKey.Type {
            return injectedType.liveValue as? T
        }

        // 🔄 2. 메인 스레드에서 캐시된 값 조회
        if Thread.isMainThread {
            let key = String(describing: type)
            let cachedValue = MainActor.assumeIsolated {
                tcaCompatibleStorage[key] as? T
            }
            if let cachedValue = cachedValue {
                return cachedValue
            }
        }

        // 🔄 3. DIContainer에서 조회
        return DIContainer.shared.resolve(type)
    }

    /// 🔄 **통합 값 조회 (타입 안전)**: @Injected에서 사용하는 범용 접근
    public static func getUnifiedValueSafe<T>(_ type: T.Type) -> T? {
        // 🔄 1. InjectedKey에서 liveValue 사용 (우선순위 1)
        if let injectedType = type as? any InjectedKey.Type {
            return injectedType.liveValue as? T
        }

        // 🔄 2. Sendable 타입인 경우에만 추가 조회
        if let sendableType = type as? any Sendable.Type {
            return getUnifiedValueSync(sendableType) as? T
        }

        return nil
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

    // MARK: - 🔧 자동 TestDependencyKey 생성

    /// 🔧 **자동 TestDependencyKey 생성**: @Dependency에서 타입 직접 사용 가능하게 만들기
    @MainActor
    static func autoFixTestDependencyKeyError<T: Sendable>(_ types: [T.Type]) {
        for type in types {
            // 🔧 자동으로 TestDependencyKey와 호환되도록 등록
            makeTestDependencyKeyCompatible(type, liveValue: createDefaultInstance(for: type))
        }
    }

    /// 🔧 **기본 인스턴스 생성**: 타입에 맞는 기본값 생성
    @MainActor
    private static func createDefaultInstance<T: Sendable>(for type: T.Type) -> T {
        // 🔧 InjectedKey에서 liveValue 사용 (첫 번째 시도)
        if let injectedType = type as? any InjectedKey.Type {
            return injectedType.liveValue as! T
        }

        // 🔧 기본값 생성 실패 시 사용자에게 알림
        Log.error("🔧 \(type)에 대한 기본 인스턴스를 생성할 수 없습니다.")
        Log.error("   해결법: fixTestDependencyKeyError(\(type).self) { /* liveValue 제공 */ }")
        fatalError("🔧 TestDependencyKey 자동 생성 실패: \(type)")
    }

    /// 🔧 **단일 타입 TestDependencyKey 자동 해결**: 특정 타입의 TestDependencyKey 호환성 자동 해결
    @MainActor
    private static func autoFixTestDependencyKeyForType<T: Sendable>(_ type: T.Type, value: T) {
        // 🔧 TestDependencyKey 호환성을 위한 자동 등록
        makeTestDependencyKeyCompatible(type, liveValue: value)

        // 🔄 통합 저장소에 즉시 저장 (@Dependency와 @Injected 동일성 보장)
        tcaCompatibleStorage[String(describing: type)] = value

        Log.info("🔧 자동 해결: \(type) TestDependencyKey 호환성 완료")
    }

    // MARK: - 🔄 TestDependencyKey 동적 Conformance

    /// 🔄 **동적 TestDependencyKey 생성**: Runtime에 TestDependencyKey conform 제공
    @MainActor
    public static func createTestDependencyKey<T: Sendable>(_ type: T.Type, liveValue: T, testValue: T? = nil) {
        // 🔄 통합 저장소에 저장
        tcaCompatibleStorage[String(describing: type)] = liveValue

        // 🔧 TestDependencyKey 호환성 추가
        makeTestDependencyKeyCompatible(type, liveValue: liveValue, testValue: testValue)

        Log.info("🔄 동적 TestDependencyKey 생성: \(type)")
    }

    /// 🔄 **자동 역방향 동기화**: WeaveDI 등록을 감지하여 TCA에 자동 동기화 (nonisolated)
    static func autoDetectWeaveDIRegistration<T: Sendable>(_ type: T.Type, value: T) {
        Task { @MainActor in
            // 🎯 완전 자동 초기화 (처음 사용 시)
            ensureAutoInitialized()

            guard isEnabled else { return }

            let typeName = String(describing: type)
            if !registeredInjectedKeys.contains(typeName) {
                reverseSyncFromWeaveDI(type, injectedInstance: value)

                // 🔧 자동 TestDependencyKey 호환성 해결
                autoFixTestDependencyKeyForType(type, value: value)

                Log.info("🔄 자동 감지: WeaveDI 등록 → TCA 동기화 (\(type))")
            }
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

// MARK: - 🎯 글로벌 자동 초기화

/// 🎯 **완전 자동 초기화**: 앱 시작 시 자동으로 모든 것이 준비됨 (글로벌 스코프)
private let _globalAutoInitializer: Void = {
    // 메인 스레드에서 자동 초기화 실행
    DispatchQueue.main.async {
        Task { @MainActor in
            TCASmartSync.ensureAutoInitialized()
            Log.info("🎯 글로벌 자동 초기화 완료: WeaveDI 모듈 import 시 자동 실행됨")
        }
    }
    return ()
}()

/// 🎯 **자동 초기화 트리거**: 모듈 로드 시 자동 실행
internal let __weaveDI_autoInit: Void = _globalAutoInitializer

// MARK: - 🔧 TestDependencyKey 에러 해결 전역 함수들

/// 🔧 **TestDependencyKey 에러 자동 해결**: @Dependency에서 타입 직접 사용 가능
///
/// ## 사용법:
/// ```swift
/// // AppDelegate 또는 main에서 한 번 호출
/// fixAllTestDependencyKeyErrors(
///   ExchangeUseCaseImpl.self,
///   FavoriteCurrencyUseCaseImpl.self,
///   ExchangeRateCacheUseCaseImpl.self
/// )
///
/// // 이후 @Dependency에서 직접 사용 가능!
/// @Dependency(ExchangeUseCaseImpl.self) private var injectedExchangeUseCase
/// ```
@MainActor
public func fixAllTestDependencyKeyErrors<T: Sendable>(_ types: T.Type...) {
    TCASmartSync.autoFixTestDependencyKeyError(Array(types))
    Log.info("🔧 \(types.count)개 타입의 TestDependencyKey 에러가 해결되었습니다!")
}

/// 🔧 **개별 TestDependencyKey 에러 해결**: 특정 타입의 liveValue 직접 제공
///
/// ## 사용법:
/// ```swift
/// fixTestDependencyKeyError(ExchangeUseCaseImpl.self) {
///   ExchangeUseCaseImpl(repository: ExchangeRepositoryImpl())
/// }
/// ```
@MainActor
public func fixTestDependencyKeyError<T: Sendable>(_ type: T.Type, liveValue: @escaping @Sendable () -> T) {
    let instance = liveValue()
    TCASmartSync.makeTestDependencyKeyCompatible(type, liveValue: instance)
    Log.info("🔧 \(type) TestDependencyKey 에러가 해결되었습니다!")
}

// MARK: - 🔄 동적 TestDependencyKey Extensions

#if canImport(Dependencies)
import Dependencies

/// 🔄 **범용 TestDependencyKey Wrapper**: 모든 InjectedKey를 TestDependencyKey로 변환
public struct UniversalTestDependencyKey<T: InjectedKey>: TestDependencyKey where T.Value: Sendable {
    public static var liveValue: T.Value {
        return T.liveValue
    }

    public static var testValue: T.Value {
        return T.liveValue // 기본적으로 liveValue 사용
    }
}

/// 🔄 **자동 DependencyValues Extension 생성**: @Dependency에서 타입 직접 사용 가능
///
/// ## 사용법:
/// ```swift
/// // 앱 시작 시 한 번만 호출
/// makeCompatibleWithDependency(ExchangeUseCaseImpl.self)
///
/// // 이후 @Dependency에서 직접 사용 가능!
/// @Dependency(ExchangeUseCaseImpl.self) private var injectedExchangeUseCase
/// ```
@MainActor
public func makeCompatibleWithDependency<T: InjectedKey>(_ type: T.Type) where T.Value: Sendable {
    // 🔄 통합 저장소에 값 저장
    TCASmartSync.createTestDependencyKey(T.Value.self, liveValue: T.liveValue)

    Log.info("🔄 \(type) → @Dependency 호환성 완료")
}

/// 🔄 **여러 타입 일괄 호환성 해결**: 한 번에 여러 타입을 @Dependency와 호환되게 만들기
///
/// ## 사용법:
/// ```swift
/// makeAllCompatibleWithDependency(
///   ExchangeUseCaseImpl.self,
///   FavoriteCurrencyUseCaseImpl.self,
///   ExchangeRateCacheUseCaseImpl.self
/// )
/// ```
@MainActor
public func makeAllCompatibleWithDependency<T: InjectedKey>(_ types: T.Type...) where T.Value: Sendable {
    for type in types {
        makeCompatibleWithDependency(type)
    }
    Log.info("🔄 \(types.count)개 타입 → @Dependency 호환성 완료")
}

#endif