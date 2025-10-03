//
//  SimpleKeyPathRegistry.swift
//  DiContainer
//
//  Created by Wonja Suh on 9/24/25.
//

import Foundation
import LogMacro

/// KeyPath 기반 의존성 등록을 위한 간편한 API를 제공합니다.
///
/// ## 사용 예시:
/// ```swift
/// SimpleKeyPathRegistry.register(\.userService) { UserServiceImpl() }
///
/// SimpleKeyPathRegistry.registerIf(\.analytics, condition: !isDebug) {
///     FirebaseAnalytics()
/// }
/// ```
public enum SimpleKeyPathRegistry {

  // MARK: - Core Registration

  /// KeyPath를 통한 팩토리 등록
  public static func register<T>(
    _ keyPath: KeyPath<WeaveDI.Container, T?>,
    factory: @escaping @Sendable () -> T
  ) where T: Sendable {
    let keyPathName = extractKeyPathName(keyPath)
    #logInfo("📝 [SimpleKeyPathRegistry] Registering \(keyPathName) -> \(T.self)")

    _ = UnifiedDI.register(T.self, factory: factory)
  }

  // MARK: - Conditional Registration

  /// 조건부 등록 (condition이 true일 때만 등록)
  public static func registerIf<T>(
    _ keyPath: KeyPath<WeaveDI.Container, T?>,
    condition: Bool,
    factory: @escaping @Sendable () -> T
  ) where T: Sendable {
    let keyPathName = extractKeyPathName(keyPath)

    guard condition else {
      #logInfo("⏭️ [SimpleKeyPathRegistry] Skipping \(keyPathName) -> \(T.self) (condition: false)")
      return
    }

    #logInfo("✅ [SimpleKeyPathRegistry] Condition met for \(keyPathName) -> \(T.self)")
    register(keyPath, factory: factory)
  }

  // MARK: - Instance Registration

  /// 이미 생성된 인스턴스 등록
  public static func registerInstance<T>(
    _ keyPath: KeyPath<WeaveDI.Container, T?>,
    instance: T
  ) where T: Sendable {
    let keyPathName = extractKeyPathName(keyPath)
    #logInfo("📦 [SimpleKeyPathRegistry] Registering instance \(keyPathName) -> \(type(of: instance))")

    _ = UnifiedDI.register(T.self) { instance }
  }

  // MARK: - Environment-Specific Registration

  /// 디버그 빌드에서만 등록
  public static func registerForDebug<T>(
    _ keyPath: KeyPath<WeaveDI.Container, T?>,
    factory: @escaping @Sendable () -> T
  ) where T: Sendable {
    let keyPathName = extractKeyPathName(keyPath)

    #if DEBUG
    #logInfo("🐛 [SimpleKeyPathRegistry] Debug-only registration: \(keyPathName)")
    register(keyPath, factory: factory)
    #else
    #logInfo("🚫 [SimpleKeyPathRegistry] Skipping debug registration: \(keyPathName) (Release build)")
    #endif
  }

  /// 릴리즈 빌드에서만 등록
  public static func registerForRelease<T>(
    _ keyPath: KeyPath<WeaveDI.Container, T?>,
    factory: @escaping @Sendable () -> T
  ) where T: Sendable {
    let keyPathName = extractKeyPathName(keyPath)

    #if DEBUG
    #logInfo("🚫 [SimpleKeyPathRegistry] Skipping release registration: \(keyPathName) (Debug build)")
    #else
    #logInfo("🚀 [SimpleKeyPathRegistry] Release-only registration: \(keyPathName)")
    register(keyPath, factory: factory)
    #endif
  }

  // MARK: - Debugging and Utilities

  /// 특정 KeyPath의 등록 상태 확인
  public static func isRegistered<T>(_ keyPath: KeyPath<WeaveDI.Container, T?>) -> Bool where T: Sendable {
    let keyPathName = extractKeyPathName(keyPath)
    #logInfo("🔍 [SimpleKeyPathRegistry] Checking registration for \(keyPathName)")
    // UnifiedDI를 통해 등록 상태 확인
    return UnifiedDI.resolve(T.self) != nil
  }

  /// KeyPath에서 이름 추출
  public static func extractKeyPathName<T>(_ keyPath: KeyPath<WeaveDI.Container, T?>) -> String {
    let keyPathString = String(describing: keyPath)

    // KeyPath 문자열에서 프로퍼티 이름 추출
    // 예: \WeaveDI.Container.userService -> userService
    if let dotIndex = keyPathString.lastIndex(of: ".") {
      let propertyName = String(keyPathString[keyPathString.index(after: dotIndex)...])
      return propertyName
    }

    return keyPathString
  }
}

// MARK: - Safe DependencyKey Helper

/// 안전한 DependencyKey 패턴을 위한 헬퍼
public enum SimpleSafeDependencyRegister {

  /// KeyPath로 안전하게 의존성 해결
  public static func safeResolve<T>(_ keyPath: KeyPath<WeaveDI.Container, T?>) -> T? where T: Sendable {
    let keyPathName = SimpleKeyPathRegistry.extractKeyPathName(keyPath)

    // UnifiedDI를 통해 해결
    if let resolved: T = UnifiedDI.resolve(T.self) {
      #logInfo("✅ [SimpleSafeDependencyRegister] Resolved \(keyPathName): \(type(of: resolved))")
      return resolved
    } else {
      #logInfo("⚠️ [SimpleSafeDependencyRegister] Failed to resolve \(keyPathName)")
      return nil
    }
  }

  /// KeyPath로 의존성 해결 (기본값 포함)
  public static func safeResolveWithFallback<T>(
    _ keyPath: KeyPath<WeaveDI.Container, T?>,
    fallback: @autoclosure () -> T
  ) -> T where T: Sendable {
    let keyPathName = SimpleKeyPathRegistry.extractKeyPathName(keyPath)

    if let resolved: T = UnifiedDI.resolve(T.self) {
      return resolved
    } else {
      let fallbackInstance = fallback()
      #logInfo("🔄 [SimpleSafeDependencyRegister] Using fallback for \(keyPathName): \(type(of: fallbackInstance))")
      return fallbackInstance
    }
  }
}