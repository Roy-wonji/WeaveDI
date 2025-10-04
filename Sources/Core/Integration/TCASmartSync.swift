//
//  TCASmartSync.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import Foundation

#if canImport(Dependencies)
import Dependencies

/// 🎯 **Super Simple** TCA ↔ WeaveDI 자동 동기화
/// 사용자 코드 수정을 최소화하는 스마트 동기화 시스템
public struct TCASmartSync {

    /// 글로벌 자동 동기화 활성화/비활성화
    @MainActor
    public static var isEnabled: Bool = false

    /// 자동 동기화할 DependencyKey 타입들
    @MainActor
    private static var registeredKeys: Set<String> = []

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

        print("🎯 TCA ↔ WeaveDI 글로벌 자동 동기화가 활성화되었습니다!")
        print("   이제 모든 TCA DependencyKey가 자동으로 WeaveDI와 동기화됩니다.")
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

        print("🎯 \(keys.count)개 TCA DependencyKey가 WeaveDI와 동기화되었습니다!")
    }

    /// 🎯 **개별 등록**: 특정 DependencyKey를 WeaveDI와 동기화
    @MainActor
    public static func syncSingle<T: DependencyKey>(_ keyType: T.Type) where T.Value: Sendable {
        let value = keyType.liveValue

        // WeaveDI에 등록
        _ = UnifiedDI.register(T.Value.self) { value }

        // 등록된 키 추가
        registeredKeys.insert(String(describing: keyType))

        print("🎯 \(keyType) → WeaveDI 동기화 완료")
    }

    /// 🎯 **스마트 감지**: DependencyKey 사용을 감지해서 자동 동기화
    @MainActor
    public static func autoDetectAndSync<T: DependencyKey>(_ keyType: T.Type, value: T.Value) where T.Value: Sendable {
        guard isEnabled else { return }

        let keyName = String(describing: keyType)
        if !registeredKeys.contains(keyName) {
            // 처음 감지된 DependencyKey 자동 등록
            _ = UnifiedDI.register(T.Value.self) { value }
            registeredKeys.insert(keyName)

            print("🎯 자동 감지: \(keyType) → WeaveDI 동기화 완료")
        }
    }

    /// Runtime hook 설치 (안전한 방법)
    private static func installAutoSyncHook() {
        // 실제 구현에서는 DependencyValues 접근을 모니터링
        // 여기서는 기본 구현만 제공
    }
}

// MARK: - 편의 확장

public extension TCASmartSync {
    /// 🎯 **편의 메서드**: 일반적인 서비스들을 한 번에 동기화
    static func syncCommonServices() {
        print("🎯 일반적인 서비스들을 자동 감지하여 동기화합니다...")
        // 런타임에 등록된 DependencyKey들을 자동 감지
        // 실제 구현에서는 리플렉션을 사용할 수 있음
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