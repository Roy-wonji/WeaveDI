//
//  SimpleKeyPathRegistry.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// 간단한 KeyPath 기반 의존성 등록 시스템
///
/// ## 사용법:
/// ```swift
/// // 1. 기본 등록
/// SimpleKeyPathRegistry.register(\.userService) { UserServiceImpl() }
///
/// // 2. 조건부 등록
/// SimpleKeyPathRegistry.registerIf(\.analytics, condition: !isDebug) {
///     AnalyticsServiceImpl()
/// }
/// ```
public enum SimpleKeyPathRegistry {

  // MARK: - Core Registration Methods

  /// KeyPath 기반 기본 등록
  public static func register<T>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    factory: @escaping @Sendable () -> T,
    file: String = #fileID,
    function: String = #function,
    line: Int = #line
  ) where T: Sendable {
    let keyPathName = extractKeyPathName(keyPath)
    #logInfo("📝 [SimpleKeyPathRegistry] Registering \(keyPathName) -> \(T.self)")

    // AutoRegister 시스템 사용
    _ = DI.register(T.self, factory: factory)
  }

  /// KeyPath 기반 조건부 등록
  public static func registerIf<T>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    condition: Bool,
    factory: @escaping @Sendable () -> T,
    file: String = #fileID,
    function: String = #function,
    line: Int = #line
  ) where T: Sendable {
    let keyPathName = extractKeyPathName(keyPath)

    guard condition else {
      #logInfo("⏭️ [SimpleKeyPathRegistry] Skipping \(keyPathName) -> \(T.self) (condition: false)")
      return
    }

    #logInfo("✅ [SimpleKeyPathRegistry] Condition met for \(keyPathName) -> \(T.self)")
    register(keyPath, factory: factory, file: file, function: function, line: line)
  }

  /// KeyPath 기반 인스턴스 등록
  public static func registerInstance<T: Sendable>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    instance: T,
    file: String = #fileID,
    function: String = #function,
    line: Int = #line
  ) {
    let keyPathName = extractKeyPathName(keyPath)
    #logInfo("📦 [SimpleKeyPathRegistry] Registering instance \(keyPathName) -> \(type(of: instance))")

    // AutoRegister 시스템 사용
    _ = DI.register(T.self) { instance }
  }

  // MARK: - Environment-based Registration

  /// Debug 환경에서만 등록
  public static func registerIfDebug<T>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    factory: @escaping @Sendable () -> T,
    file: String = #fileID,
    function: String = #function,
    line: Int = #line
  ) where T: Sendable {
#if DEBUG
    let keyPathName = extractKeyPathName(keyPath)
    #logInfo("🐛 [SimpleKeyPathRegistry] Debug-only registration: \(keyPathName)")
    register(keyPath, factory: factory, file: file, function: function, line: line)
#else
    let keyPathName = extractKeyPathName(keyPath)
    #logInfo("🚫 [SimpleKeyPathRegistry] Skipping debug registration: \(keyPathName) (Release build)")
#endif
  }

  /// Release 환경에서만 등록
  public static func registerIfRelease<T>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    factory: @escaping @Sendable () -> T,
    file: String = #fileID,
    function: String = #function,
    line: Int = #line
  ) where T: Sendable {
#if DEBUG
    let keyPathName = extractKeyPathName(keyPath)
    #logInfo("🚫 [SimpleKeyPathRegistry] Skipping release registration: \(keyPathName) (Debug build)")
#else
    let keyPathName = extractKeyPathName(keyPath)
    #logInfo("🚀 [SimpleKeyPathRegistry] Release-only registration: \(keyPathName)")
    register(keyPath, factory: factory, file: file, function: function, line: line)
#endif
  }

  // MARK: - Debugging and Utilities

  /// 특정 KeyPath의 등록 상태 확인
  public static func isRegistered<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> Bool {
    let keyPathName = extractKeyPathName(keyPath)
    #logInfo("🔍 [SimpleKeyPathRegistry] Checking registration for \(keyPathName)")
    // AutoRegistrationRegistry의 isRegistered 메서드 사용
    return AutoRegistrationRegistry.shared.isRegistered(T.self)
  }

  /// KeyPath에서 이름 추출
  public static func extractKeyPathName<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> String {
    let keyPathString = String(describing: keyPath)

    // KeyPath 문자열에서 프로퍼티 이름 추출
    // 예: \DependencyContainer.userService -> userService
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
  public static func safeResolve<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> T? {
    let keyPathName = SimpleKeyPathRegistry.extractKeyPathName(keyPath)

    // AutoRegistrationRegistry의 resolve 메서드 사용
    if let resolved: T = AutoRegistrationRegistry.shared.resolve(T.self) {
      #logInfo("✅ [SimpleSafeDependencyRegister] Resolved \(keyPathName): \(type(of: resolved))")
      return resolved
    } else {
      #logInfo("⚠️ [SimpleSafeDependencyRegister] Failed to resolve \(keyPathName)")
      return nil
    }
  }

  /// KeyPath로 의존성 해결 (기본값 포함)
  public static func resolveWithFallback<T>(
    _ keyPath: KeyPath<DependencyContainer, T?>,
    fallback: @autoclosure () -> T
  ) -> T {
    if let resolved = safeResolve(keyPath) {
      return resolved
    } else {
      let fallbackInstance = fallback()
      let keyPathName = SimpleKeyPathRegistry.extractKeyPathName(keyPath)
      #logInfo("🔄 [SimpleSafeDependencyRegister] Using fallback for \(keyPathName): \(type(of: fallbackInstance))")
      return fallbackInstance
    }
  }
}
