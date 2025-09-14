//
//  DIRegistration.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - DI Registration API

public extension DI {

    // MARK: - Registration

    /// 의존성을 팩토리 패턴으로 등록합니다
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: 등록 해제 핸들러
    @discardableResult
    static func register<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> () -> Void {
        return DependencyContainer.live.register(type, build: factory)
    }

    /// KeyPath 기반으로 의존성을 등록하고 생성된 인스턴스를 즉시 반환합니다
    /// - Parameters:
    ///   - keyPath: `DependencyContainer` 내의 의존성 위치(해결 시 사용), 단순한 식별 용도
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: 생성된 인스턴스 (동시에 DI 컨테이너에 싱글톤으로 등록됨)
    @discardableResult
    static func register<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T
    ) -> T {
        let instance = factory()
        DependencyContainer.live.register(T.self, instance: instance)
        return instance
    }

    /// 의존성을 조건부로 등록합니다
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - condition: 등록 조건
    ///   - factory: 인스턴스를 생성하는 클로저
    ///   - fallback: 조건이 false일 때 사용할 팩토리
    @discardableResult
    static func registerIf<T>(
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

    /// KeyPath 기반 조건부 등록 (등록과 동시에 인스턴스 반환)
    @discardableResult
    static func registerIf<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        condition: Bool,
        factory: @escaping @Sendable () -> T,
        fallback: @escaping @Sendable () -> T
    ) -> T {
        return condition ? register(keyPath, factory: factory) : register(keyPath, factory: fallback)
    }
}