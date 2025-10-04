//
//  AutoSyncMacros.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

/// 🎯 **Super Simple** TCA → WeaveDI 자동 동기화 매크로
///
/// ## 💡 사용자가 원하는 패턴 (기존 코드 그대로!):
/// ```swift
/// @AutoSync  // ← 이것만 추가!
/// extension DependencyValues {
///   var myService: MyService {
///     get { self[MyServiceKey.self] }  // 기존 코드 그대로
///     set { self[MyServiceKey.self] = newValue }  // 기존 코드 그대로
///   }
/// }
/// ```
///
/// ## 매크로가 자동으로 동기화 extension을 추가 생성:
/// ```swift
/// // 기존 extension (그대로 유지)
/// extension DependencyValues {
///   var myService: MyService {
///     get { self[MyServiceKey.self] }
///     set { self[MyServiceKey.self] = newValue }
///   }
/// }
///
/// // 매크로가 자동 생성하는 동기화 extension
/// extension DependencyValues {
///   var myServiceSync: MyService {
///     get {
///       let value = self[MyServiceKey.self]
///       TCAAutoSyncContainer.autoSyncToWeaveDI(MyService.self, value: value)
///       return value
///     }
///     set {
///       self[MyServiceKey.self] = newValue
///       TCAAutoSyncContainer.autoSyncToWeaveDI(MyService.self, value: newValue)
///     }
///   }
/// }
/// ```
@attached(member, names: arbitrary)
public macro AutoSync() = #externalMacro(module: "WeaveDIMacros", type: "AutoSyncMacro")

/// Individual property용 자동 동기화 매크로
@attached(peer)
public macro AutoSyncProperty(key: Any.Type) = #externalMacro(module: "WeaveDIMacros", type: "AutoSyncPropertyMacro")

/// 🎉 **가장 간단한 매크로**: 완전한 동기화 property를 한 줄로 생성!
///
/// ## 사용법:
/// ```swift
/// extension DependencyValues {
///   @GenerateAutoSync(key: MyServiceKey.self, type: MyService.self)
///   // ↑ 이 한 줄이 완전한 동기화 property를 자동 생성!
/// }
/// ```
///
/// ## 생성 결과:
/// ```swift
/// extension DependencyValues {
///   var myService: MyService {
///     get {
///       let value = self[MyServiceKey.self]
///       TCAAutoSyncContainer.autoSyncToWeaveDI(MyService.self, value: value)
///       return value
///     }
///     set {
///       self[MyServiceKey.self] = newValue
///       TCAAutoSyncContainer.autoSyncToWeaveDI(MyService.self, value: newValue)
///     }
///   }
/// }
/// ```
@attached(member, names: arbitrary)
public macro GenerateAutoSync(key: Any.Type, type: Any.Type) = #externalMacro(module: "WeaveDIMacros", type: "GenerateAutoSyncMacro")

/// WeaveDI 자동 동기화를 지원하는 마커 프로토콜
public protocol WeaveDIAutoSyncable {
    /// WeaveDI로 자동 동기화하는 헬퍼 메서드
    func autoSyncToWeaveDI<T: Sendable>(_ type: T.Type, value: T)
}

// MARK: - DependencyValues Auto Sync Support

#if canImport(Dependencies)
import Dependencies

extension DependencyValues: WeaveDIAutoSyncable {
    /// TCA DependencyValues에서 WeaveDI로 자동 동기화
    public func autoSyncToWeaveDI<T: Sendable>(_ type: T.Type, value: T) {
        TCAAutoSyncContainer.autoSyncToWeaveDI(type, value: value)
    }
}
#endif

// MARK: - Simplified Usage

/// 사용자 친화적인 매크로 사용을 위한 헬퍼
public struct WeaveDIAutoSync {
    /// 📖 사용법 가이드
    ///
    /// ## TCA computed property 자동 동기화:
    /// ```swift
    /// extension DependencyValues {
    ///   @AutoSyncProperty
    ///   var myService: MyService {
    ///     get { self[MyServiceKey.self] }
    ///     set { self[MyServiceKey.self] = newValue }
    ///   }
    /// }
    /// ```
    ///
    /// ## Extension 전체 자동 동기화:
    /// ```swift
    /// @AutoSync
    /// extension DependencyValues {
    ///   var service1: Service1 { ... }
    ///   var service2: Service2 { ... }
    /// }
    /// ```
    public static let usageGuide = """
    사용법:
    1. @AutoSync - extension 전체에 적용
    2. @AutoSyncProperty - 개별 property에 적용
    """
}