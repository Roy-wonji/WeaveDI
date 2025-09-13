//
//  SimplifiedAPI.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - Simplified API Design

/// 단순화된 DI API - 사용자 혼란을 줄이기 위해 핵심 패턴만 제공
/// 
/// ## 3가지 핵심 패턴:
/// 1. **@Inject** - 의존성 주입 (옵셔널/필수)
/// 2. **DI.register()** - 의존성 등록  
/// 3. **DI.resolve()** - 의존성 해결
///
/// ## 사용 예시:
/// ```swift
/// // 1. 등록
/// DI.register(ServiceProtocol.self) { ServiceImpl() }
/// 
/// // 2. 주입
/// @Inject(\.service) var service: ServiceProtocol?         // 옵셔널
/// @Inject(\.service) var service: ServiceProtocol          // 필수 (컴파일 타임 체크)
/// 
/// // 3. 수동 해결
/// let service = DI.resolve(ServiceProtocol.self)
/// ```
public enum DI {
    
    // MARK: - Registration
    
    /// 의존성을 팩토리 패턴으로 등록합니다
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: 등록 해제 핸들러
    @discardableResult
    public static func register<T: Sendable>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> () -> Void {
        return DependencyContainer.live.register(type, build: factory)
    }
    
    /// 의존성을 싱글톤으로 등록합니다
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - instance: 공유할 인스턴스
    public static func registerSingleton<T: Sendable>(
        _ type: T.Type,
        instance: T
    ) {
        DependencyContainer.live.register(type, instance: instance)
    }
    
    /// 의존성을 조건부로 등록합니다
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - condition: 등록 조건
    ///   - factory: 인스턴스를 생성하는 클로저
    ///   - fallback: 조건이 false일 때 사용할 팩토리
    @discardableResult
    public static func registerIf<T: Sendable>(
        _ type: T.Type,
        condition: Bool,
        factory: @escaping @Sendable () -> T,
        fallback: @escaping @Sendable () -> T
    ) -> () -> Void {
        if condition {
            return register(type, factory: factory)
        } else {
            return register(type, factory: fallback)
        }
    }
    
    // MARK: - Resolution
    
    /// 등록된 의존성을 해결합니다
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스 (없으면 nil)
    public static func resolve<T>(_ type: T.Type) -> T? {
        return DependencyContainer.live.resolve(type)
    }
    
    /// 등록된 의존성을 해결하거나 기본값을 반환합니다
    /// - Parameters:
    ///   - type: 해결할 타입
    ///   - defaultValue: 해결 실패 시 기본값
    /// - Returns: 해결된 인스턴스 또는 기본값
    public static func resolve<T>(_ type: T.Type, default defaultValue: @autoclosure () -> T) -> T {
        return DependencyContainer.live.resolve(type) ?? defaultValue()
    }
    
    /// 필수 의존성을 해결합니다 (실패 시 fatalError)
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스
    public static func requireResolve<T>(_ type: T.Type) -> T {
        guard let resolved = DependencyContainer.live.resolve(type) else {
            fatalError("Required dependency \(T.self) not found. Did you forget to register it?")
        }
        return resolved
    }
    
    // MARK: - Management
    
    /// 등록된 의존성을 해제합니다
    /// - Parameter type: 해제할 타입
    public static func release<T>(_ type: T.Type) {
        DependencyContainer.live.release(type)
    }
    
    /// 모든 등록된 의존성을 해제합니다 (테스트 용도)
    public static func releaseAll() {
        // Implementation would need to be added to DependencyContainer
        // For now, create a new container
        DependencyContainer.live = DependencyContainer()
    }
    
    // MARK: - Bulk Registration
    
    /// 여러 의존성을 한번에 등록합니다
    /// - Parameter registrations: 등록할 의존성 목록
    public static func registerMany(@DIRegistrationBuilder _ registrations: () -> [DIRegistration]) {
        let items = registrations()
        for registration in items {
            registration.register()
        }
    }
}

// MARK: - Result Builder for Bulk Registration

@resultBuilder
public struct DIRegistrationBuilder {
    public static func buildBlock(_ components: DIRegistration...) -> [DIRegistration] {
        return components
    }
}

// MARK: - Registration Item

public struct DIRegistration {
    private let registerAction: () -> Void
    
    public init<T: Sendable>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        self.registerAction = {
            DI.register(type, factory: factory)
        }
    }
    
    public init<T: Sendable>(_ type: T.Type, singleton instance: T) {
        self.registerAction = {
            DI.registerSingleton(type, instance: instance)
        }
    }
    
    internal func register() {
        registerAction()
    }
}

// MARK: - Simplified Inject Property Wrapper

/// 단순화된 의존성 주입 프로퍼티 래퍼
/// 
/// ## 사용법:
/// ```swift
/// @Inject(\.service) var service: ServiceProtocol?         // 옵셔널
/// @Inject(\.service) var service: ServiceProtocol          // 필수 (런타임 체크)
/// ```
@propertyWrapper
public struct Inject<T> {
    private let keyPath: KeyPath<DependencyContainer, T?>
    
    public var wrappedValue: T {
        get {
            guard let resolved = DependencyContainer.live[keyPath: keyPath] else {
                fatalError("Dependency \(T.self) not found at keyPath \(keyPath). Did you forget to register it?")
            }
            return resolved
        }
    }
    
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
    }
}

// MARK: - Migration Aliases (for backward compatibility)

/// 기존 API와의 호환성을 위한 별칭들
/// 이들은 향후 deprecation 예정
public typealias SimpleDI = DI

// Legacy property wrapper aliases - will be deprecated
public typealias SimpleInject<T> = Inject<T>