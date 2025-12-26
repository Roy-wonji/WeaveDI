//
//  WeaveDI.swift
//  WeaveDI
//
//  🚀 TCA-Style Dependency Injection Library
//  Swift 6 Compatible, Ultra-Lightweight, High-Performance
//

import Foundation

// MARK: - 🎯 Selective Core Exports

// 기존 WeaveDICore 기능 선별적 import
import WeaveDICore

// ✅ 권장 타입들만 public으로 re-export (충돌 방지)
public typealias Injected = WeaveDICore.Injected
public typealias InjectedValues = WeaveDICore.InjectedValues
public typealias InjectedManager = WeaveDICore.InjectedManager
public typealias UnifiedDI = WeaveDICore.UnifiedDI
public typealias DIContainer = WeaveDICore.DIContainer
public typealias Container = WeaveDICore.DIContainer  // ✅ 사용자 호환성을 위한 별칭
public typealias DIError = WeaveDICore.DIError
public typealias ProvideScope = WeaveDICore.ProvideScope
public typealias InjectedKey = WeaveDICore.InjectedKey
public typealias ComponentProtocol = WeaveDICore.ComponentProtocol
public typealias DIContainerActor = WeaveDICore.DIContainerActor

// 🚨 충돌 방지: TCA 타입들을 export하지 않음
// ComposableArchitecture와 충돌 방지를 위해 제거
// 필요시 WeaveDI.InjectedValues, WeaveDI.InjectedKey 등으로 명시적 사용

// ✅ WeaveDI 고유 타입들만 사용 권장:
// - @Injected var service: ServiceType
// - @WeaveDI.Injected(\.service) var service: ServiceType
// - UnifiedDI.register { ServiceImpl() }

// 🎨 새로운 TCA 스타일 API export (자동으로 사용 가능)
// - @DependencyConfiguration (DependencyBuilder.swift)
// - DependencyEnvironment (DependencyBuilder.swift)

// MARK: - 🎨 Enhanced TCA-Style API

/// **WeaveDI** - TCA 스타일 확장 API with Builder Pattern
///
/// ### 🚀 새로운 사용법 (더 간단!):
/// ```swift
/// // 1. 타입 추론으로 간단한 등록
/// WeaveDI.register { UserServiceImpl() }      // UserService로 자동 등록
///
/// // 2. TCA 스타일 사용
/// @Injected var userService: UserService     // 키패스 없이 타입만으로!
/// ```
public enum WeaveDI {

    // MARK: - 타입 추론 등록

    /// 🎯 **타입 추론으로 간단하게 등록!**
    ///
    /// ### 사용법:
    /// ```swift
    /// WeaveDI.register { UserServiceImpl() }      // UserService로 자동 등록
    /// WeaveDI.register { RepositoryImpl() }       // Repository로 자동 등록
    /// ```
    @discardableResult
    public static func register<T: Sendable>(_ factory: @escaping @Sendable () -> T) -> T {
        return UnifiedDI.register(T.self, factory: factory)
    }

    /// 🎯 **체이닝 등록 시작**
    ///
    /// ### 사용법:
    /// ```swift
    /// WeaveDI.builder
    ///     .register { UserServiceImpl() }
    ///     .register { RepositoryImpl() }
    ///     .configure()
    /// ```
    public static var builder: RegistrationBuilder {
        RegistrationBuilder()
    }

    // MARK: - 환경별 등록

    /// 🌍 **환경에 따른 자동 등록**
    ///
    /// ### 사용법:
    /// ```swift
    /// WeaveDI.registerForEnvironment { env in
    ///     if env.isDebug {
    ///         env.register { MockUserService() as UserService }
    ///     } else {
    ///         env.register { UserServiceImpl() as UserService }
    ///     }
    /// }
    /// ```
    public static func registerForEnvironment(_ configure: (EnvironmentBuilder) -> Void) {
        let builder = EnvironmentBuilder()
        configure(builder)
    }
}

// MARK: - 체이닝 빌더

/// 체이닝 등록을 위한 빌더
public struct RegistrationBuilder {

    @discardableResult
    public func register<T: Sendable>(_ factory: @escaping @Sendable () -> T) -> RegistrationBuilder {
        _ = WeaveDI.register(factory)
        return self
    }

    public func configure() {
        // 등록 완료
    }
}

// MARK: - 환경별 빌더

/// 환경별 등록을 위한 빌더
public struct EnvironmentBuilder {

    /// 현재 환경이 디버그인지 확인
    public var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// 현재 환경이 테스트인지 확인
    public var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// 환경별 등록
    @discardableResult
    public func register<T: Sendable>(_ factory: @escaping @Sendable () -> T) -> EnvironmentBuilder {
        _ = WeaveDI.register(factory)
        return self
    }
}
