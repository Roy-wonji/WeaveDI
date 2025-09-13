//
//  DependencyScope.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation

// MARK: - DependencyScope Protocol

/// 의존성 스코프를 정의하는 프로토콜입니다.
/// 
/// Needle 스타일의 컴파일 타임 검증을 위한 기반 프로토콜로,
/// 각 모듈의 의존성과 제공하는 서비스를 명시적으로 정의합니다.
public protocol DependencyScope {
    /// 이 스코프가 필요로 하는 의존성들의 타입
    associatedtype Dependencies
    
    /// 이 스코프가 제공하는 서비스들의 타입
    associatedtype Provides
    
    /// 의존성 검증을 수행합니다.
    /// - Returns: 모든 의존성이 유효한 경우 true
    static func validate() -> Bool
}

// MARK: - EmptyDependencies

/// 의존성이 없는 경우 사용하는 타입입니다.
public struct EmptyDependencies {
    public init() {}
}

// MARK: - Default Implementation

public extension DependencyScope {
    /// 기본 검증 구현
    /// 실제 검증 로직은 컴파일 타임에 생성되거나 
    /// 각 스코프에서 오버라이드하여 구현합니다.
    static func validate() -> Bool {
        // TODO: 컴파일 타임 검증 로직 구현
        return true
    }
}

// MARK: - DependencyValidationError

/// 의존성 검증 실패 시 발생하는 오류입니다.
public enum DependencyValidationError: Error, CustomStringConvertible {
    case missingDependency(String)
    case circularDependency(String)
    case typeMismatch(expected: String, actual: String)
    
    public var description: String {
        switch self {
        case .missingDependency(let dependency):
            return "Missing dependency: \(dependency)"
        case .circularDependency(let dependency):
            return "Circular dependency detected: \(dependency)"
        case .typeMismatch(let expected, let actual):
            return "Type mismatch: expected \(expected), got \(actual)"
        }
    }
}

// MARK: - DependencyValidation

/// 의존성 검증을 위한 헬퍼 유틸리티입니다.
public struct DependencyValidation {
    
    /// 특정 타입의 의존성이 등록되어 있는지 확인합니다.
    /// 
    /// - Parameter type: 확인할 의존성 타입
    /// - Returns: 등록 여부
    public static func isRegistered<T>(_ type: T.Type) -> Bool {
        return DependencyContainer.live.resolve(type) != nil
    }
    
    /// 여러 의존성이 모두 등록되어 있는지 확인합니다.
    /// 
    /// - Parameter types: 확인할 의존성 타입들
    /// - Returns: 모든 의존성이 등록되어 있으면 true
    public static func areRegistered(_ types: [Any.Type]) -> Bool {
        // 런타임에서는 실제 해결 가능 여부를 확인
        // 컴파일 타임에서는 매크로나 코드 생성으로 처리
        return true
    }
    
    /// 의존성 그래프에 순환 참조가 있는지 확인합니다.
    /// 
    /// - Parameter startType: 검사를 시작할 타입
    /// - Returns: 순환 참조 여부
    public static func hasCircularDependency<T>(_ startType: T.Type) -> Bool {
        // TODO: 실제 순환 참조 감지 로직 구현
        return false
    }
}

// MARK: - 예시 스코프 정의들

/// 네트워크 관련 의존성 스코프 예시
public struct NetworkScope: DependencyScope {
    public typealias Dependencies = EmptyDependencies
    public typealias Provides = NetworkServiceProtocol
    
    public static func validate() -> Bool {
        // NetworkService는 다른 의존성이 필요하지 않음
        return true
    }
}

/// 사용자 관련 의존성 스코프 예시
public struct UserScope: DependencyScope {
    public typealias Dependencies = NetworkServiceProtocol
    public typealias Provides = (UserRepositoryProtocol, UserUseCaseProtocol)
    
    public static func validate() -> Bool {
        // NetworkService가 등록되어 있는지 확인
        return DependencyValidation.isRegistered(NetworkServiceProtocol.self)
    }
}

// MARK: - Protocol 정의 (예시)

/// 네트워크 서비스 프로토콜 예시
public protocol NetworkServiceProtocol {
    func request(_ url: String) async -> Data
}

/// 사용자 리포지토리 프로토콜 예시  
public protocol UserRepositoryProtocol {
    func fetchUser(id: String) async -> User?
}

/// 사용자 유스케이스 프로토콜 예시
public protocol UserUseCaseProtocol {
    func getUser(id: String) async -> User?
}

/// 사용자 모델 예시
public struct User {
    public let id: String
    public let name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}