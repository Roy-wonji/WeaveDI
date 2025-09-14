//
//  DIResolution.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - DI Resolution API

public extension DI {

    // MARK: - Resolution

    /// 등록된 의존성을 해결합니다 (옵셔널 반환)
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스 (없으면 nil)
    static func resolve<T>(_ type: T.Type) -> T? {
        return DependencyContainer.live.resolve(type)
    }

    /// 등록된 의존성을 Result로 해결합니다 (에러 처리)
    /// - Parameter type: 해결할 타입
    /// - Returns: 성공 시 인스턴스, 실패 시 DIError
    static func resolveResult<T>(_ type: T.Type) -> Result<T, DIError> {
        if let resolved = DependencyContainer.live.resolve(type) {
            return .success(resolved)
        } else {
            return .failure(.dependencyNotFound(type, hint: "Call DI.register(\(type).self) { ... } first"))
        }
    }

    /// 등록된 의존성을 해결하고 실패 시 throws
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스
    /// - Throws: DIError.dependencyNotFound
    static func resolveThrows<T>(_ type: T.Type) throws -> T {
        if let resolved = DependencyContainer.live.resolve(type) {
            return resolved
        } else {
            throw DIError.dependencyNotFound(type, hint: "Call DI.register(\(type).self) { ... } first")
        }
    }

    /// 등록된 의존성을 해결하거나 기본값을 반환합니다
    /// - Parameters:
    ///   - type: 해결할 타입
    ///   - defaultValue: 해결 실패 시 기본값
    /// - Returns: 해결된 인스턴스 또는 기본값
    static func resolve<T>(_ type: T.Type, default defaultValue: @autoclosure () -> T) -> T {
        return DependencyContainer.live.resolve(type) ?? defaultValue()
    }

    /// 필수 의존성을 해결합니다 (실패 시 fatalError)
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스
    /// - Warning: 개발 중에만 사용하세요. 프로덕션에서는 resolveThrows() 사용 권장
    static func requireResolve<T>(_ type: T.Type) -> T {
        guard let resolved = DependencyContainer.live.resolve(type) else {
            fatalError("🚨 Required dependency '\(T.self)' not found. Register it using: DI.register(\(T.self).self) { ... }")
        }
        return resolved
    }
}