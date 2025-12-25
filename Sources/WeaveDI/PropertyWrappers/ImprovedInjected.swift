//
//  ImprovedInjected.swift
//  WeaveDI
//
//  Created by AI Assistant on 2024.
//  TCA-Style Enhanced @Injected Property Wrapper
//

import Foundation

// MARK: - Enhanced @Injected Property Wrapper

/// 🚀 **개선된 @Injected** - TCA 스타일로 타입만으로 간단하게!
///
/// ### Before (복잡함):
/// ```swift
/// struct UserServiceKey: DependencyKey {
///     static var liveValue: UserService { UserServiceImpl() }
/// }
///
/// extension DependencyValues {
///     var userService: UserService {
///         get { self[UserServiceKey.self] }
///         set { self[UserServiceKey.self] = newValue }
///     }
/// }
///
/// @Injected(\.userService) var userService: UserService
/// ```
///
/// ### After (간단함):
/// ```swift
/// @Injected var userService: UserService  // 끝!
/// ```
@propertyWrapper
public struct Injected<T: Sendable> {
    private let type: T.Type
    private var cachedValue: T?
    private let keyPath: WritableKeyPath<DependencyValues, T>?

    // MARK: - 초기화

    /// 🎯 **타입만으로 간단하게!** (새 방식 - 권장)
    ///
    /// UnifiedDI에 등록된 타입을 자동으로 해결합니다.
    ///
    /// ### 사용법:
    /// ```swift
    /// @Injected var userService: UserService
    /// @Injected var repository: Repository
    /// ```
    public init() where T: Sendable {
        self.type = T.self
        self.keyPath = nil
        self.cachedValue = nil
    }

    /// 🔄 **기존 KeyPath 방식** (호환성 유지)
    ///
    /// DependencyValues의 KeyPath를 사용하는 기존 방식입니다.
    ///
    /// ### 사용법:
    /// ```swift
    /// @Injected(\.userService) var userService: UserService
    /// ```
    public init(_ keyPath: WritableKeyPath<DependencyValues, T>) {
        self.type = T.self
        self.keyPath = keyPath
        self.cachedValue = nil
    }

    // MARK: - Property Wrapper 구현

    public var wrappedValue: T {
        mutating get {
            // 캐시된 값이 있으면 반환 (성능 최적화)
            if let cached = cachedValue {
                return cached
            }

            let resolved: T

            if let keyPath = keyPath {
                // 🔄 기존 KeyPath 방식
                resolved = DependencyManager.current[keyPath: keyPath]
            } else {
                // 🎯 새로운 타입 기반 방식
                resolved = resolveFromUnifiedDI()
            }

            // 캐시에 저장
            cachedValue = resolved
            return resolved
        }
    }

    // MARK: - Private 구현

    /// UnifiedDI에서 타입 기반으로 해결
    private func resolveFromUnifiedDI() -> T {
        // 1. UnifiedDI에서 먼저 시도
        if let resolved = UnifiedDI.resolve(type, logOnMiss: false) {
            return resolved
        }

        // 2. DependencyValues에서 기본값 시도 (TCA 호환성)
        if let defaultValue = tryResolveFromDependencyValues() {
            return defaultValue
        }

        // 3. 모두 실패하면 명확한 에러
        fatalError("""
            🚨 [WeaveDI] \(type) 의존성을 찾을 수 없습니다!

            💡 해결 방법:
            1. UnifiedDI 등록: UnifiedDI.register { YourImplementation() }
            2. DependencyKey 정의: DependencyValues에 등록

            🔍 등록이 해결보다 먼저 수행되었는지 확인하세요.
            """)
    }

    /// DependencyValues에서 기본값 시도 (TCA 호환성)
    private func tryResolveFromDependencyValues() -> T? {
        // TCA DependencyValues에서 해당 타입의 기본값을 찾으려고 시도
        // 현재는 기본 구현 (향후 확장 가능)
        return nil
    }
}

// MARK: - 편의 확장

public extension Injected {
    /// 🔄 기존 사용자를 위한 편의 초기화
    ///
    /// KeyPath와 타입을 동시에 받는 방식입니다.
    init<Key: DependencyKey>(_ keyPath: WritableKeyPath<DependencyValues, T>, key: Key.Type) where Key.Value == T {
        self.init(keyPath)
    }
}

// MARK: - UnifiedDI 통합 지원

/// @Injected에서 사용할 수 있도록 UnifiedDI 확장
public extension UnifiedDI {
    /// @Injected 전용 해결 (로그 없이)
    static func resolveForInjected<T: Sendable>(_ type: T.Type) -> T? {
        resolve(type, logOnMiss: false)
    }
}

// MARK: - 사용 예시 주석

/*

 ## 🚀 사용 예시

 ### 1. 새로운 방식 (타입만으로!)

 ```swift
 // 등록
 UnifiedDI.register { UserServiceImpl() }
 UnifiedDI.register { RepositoryImpl() }

 // 사용
 class ViewModel {
     @Injected var userService: UserService      // ✅ 간단!
     @Injected var repository: Repository        // ✅ 간단!
 }
 ```

 ### 2. 기존 방식 (호환성 유지)

 ```swift
 // DependencyKey 정의
 struct UserServiceKey: DependencyKey {
     static var liveValue: UserService { UserServiceImpl() }
 }

 extension DependencyValues {
     var userService: UserService {
         get { self[UserServiceKey.self] }
         set { self[UserServiceKey.self] = newValue }
     }
 }

 // 사용
 @Injected(\.userService) var userService: UserService
 ```

 ### 3. 환경별 설정

 ```swift
 // 개발 환경
 UnifiedDI.register { MockUserService() as UserService }

 // 프로덕션 환경
 UnifiedDI.register { UserServiceImpl() as UserService }

 // 사용은 동일
 @Injected var userService: UserService  // 환경에 따라 자동 선택!
 ```

 */