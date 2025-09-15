//
//  SafePropertyWrappers.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Safe Property Wrappers

/// 안전한 의존성 주입을 위한 프로퍼티 래퍼
///
/// ## 개요
///
/// `@SafeInject`는 기존 `@Inject`의 안전한 대안으로, fatalError 대신 throws를 사용합니다.
///
/// ## 사용 예시
///
/// ```swift
/// class UserViewController {
///     @SafeInject var userService: UserService?
///
///     func loadUser() {
///         do {
///             let service = try userService.getValue()
///             // 안전하게 서비스 사용
///         } catch {
///             // 에러 처리
///             #logDebug("서비스를 로드할 수 없습니다: \(error)")
///         }
///     }
/// }
/// ```
@propertyWrapper
public struct SafeInject<T> {

    // MARK: - Properties

    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let type: T.Type?
    private var cachedValue: T?
    private var lastError: SafeDIError?

    // MARK: - Initialization

    /// KeyPath를 사용한 초기화
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        self.type = nil
    }

    /// 타입을 사용한 초기화
    public init(_ type: T.Type) {
        self.keyPath = nil
        self.type = type
    }

    /// 기본 초기화 (타입 추론)
    public init() {
        self.keyPath = nil
        self.type = T.self
    }

    // MARK: - Property Wrapper Implementation

    public var wrappedValue: SafeResolutionResult<T> {
        mutating get {
            do {
                let value = try getValue()
                return .success(value)
            } catch let error as SafeDIError {
                self.lastError = error
                return .failure(error)
            } catch {
                let diError = SafeDIError.invalidConfiguration(reason: error.localizedDescription)
                self.lastError = diError
                return .failure(diError)
            }
        }
    }

    /// 안전한 값 가져오기 (throws)
    public mutating func getValue() throws -> T {
        // 캐시된 값이 있다면 반환
        if let cached = cachedValue {
            return cached
        }

        // 순환 의존성 탐지 시작
        if let type = type {
            try CircularDependencyDetector.shared.beginResolution(type)
        }

        defer {
            if let type = type {
                CircularDependencyDetector.shared.endResolution(type)
            }
        }

        let resolved: T?

        if let keyPath = keyPath {
            resolved = DependencyContainer.live[keyPath: keyPath]
        } else if let type = type {
            resolved = DependencyContainer.live.resolve(type)
        } else {
            throw SafeDIError.invalidConfiguration(reason: "Neither keyPath nor type specified")
        }

        guard let value = resolved else {
            if let type = type {
                throw SafeDIError.dependencyNotFound(
                    type: String(describing: type),
                    keyPath: keyPath.map { String(describing: $0) }
                )
            } else {
                throw SafeDIError.dependencyNotFound(
                    type: "Unknown",
                    keyPath: keyPath.map { String(describing: $0) }
                )
            }
        }

        self.cachedValue = value
        return value
    }

    /// 복구 전략과 함께 값 가져오기
    public mutating func getValue(strategy: RecoveryStrategy<T>) -> T? {
        return SafeDependencyResolver.safeResolve(type ?? T.self, strategy: strategy)
    }

    /// 마지막 에러 정보
    public var lastResolutionError: SafeDIError? {
        return lastError
    }
}

/// 필수 의존성을 위한 안전한 프로퍼티 래퍼
///
/// ## 개요
///
/// `@SafeRequiredInject`는 의존성이 반드시 있어야 하는 경우에 사용하며,
/// 실패 시 명확한 에러 정보를 제공합니다.
@propertyWrapper
public struct SafeRequiredInject<T> {

    // MARK: - Properties

    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let type: T.Type?
    private let context: String?
    private var cachedValue: T?

    // MARK: - Initialization

    /// KeyPath와 컨텍스트를 사용한 초기화
    public init(_ keyPath: KeyPath<DependencyContainer, T?>, context: String? = nil) {
        self.keyPath = keyPath
        self.type = nil
        self.context = context
    }

    /// 타입과 컨텍스트를 사용한 초기화
    public init(_ type: T.Type, context: String? = nil) {
        self.keyPath = nil
        self.type = type
        self.context = context
    }

    /// 기본 초기화 (타입 추론)
    public init(context: String? = nil) {
        self.keyPath = nil
        self.type = T.self
        self.context = context
    }

    // MARK: - Property Wrapper Implementation

    public var wrappedValue: T {
        mutating get {
            do {
                return try getValue()
            } catch {
                // 여기서는 여전히 fatalError를 사용하지만, 더 나은 에러 메시지 제공
                if let diError = error as? SafeDIError {
                    fatalError("""
                    🚨 [SafeRequiredInject] 필수 의존성 해결 실패

                    \(diError.debugDescription)

                    컨텍스트: \(context ?? "없음")
                    """)
                } else {
                    fatalError("🚨 [SafeRequiredInject] 알 수 없는 에러: \(error)")
                }
            }
        }
    }

    /// 안전한 값 가져오기 (throws)
    public mutating func getValue() throws -> T {
        // 캐시된 값이 있다면 반환
        if let cached = cachedValue {
            return cached
        }

        // 순환 의존성 탐지 시작
        if let type = type {
            try CircularDependencyDetector.shared.beginResolution(type)
        }

        defer {
            if let type = type {
                CircularDependencyDetector.shared.endResolution(type)
            }
        }

        let resolved: T?

        if let keyPath = keyPath {
            resolved = DependencyContainer.live[keyPath: keyPath]
        } else if let type = type {
            resolved = DependencyContainer.live.resolve(type)
        } else {
            throw SafeDIError.invalidConfiguration(reason: "Neither keyPath nor type specified")
        }

        guard let value = resolved else {
            throw SafeDIError.requiredDependencyMissing(
                type: String(describing: type ?? T.self),
                context: context
            )
        }

        self.cachedValue = value
        return value
    }
}

/// 안전한 Factory 프로퍼티 래퍼
@propertyWrapper
public struct SafeFactory<T> {

    // MARK: - Properties

    private let keyPath: KeyPath<DependencyContainer, T?>
    private var cachedValue: T?

    // MARK: - Initialization

    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
    }

    // MARK: - Property Wrapper Implementation

    public var wrappedValue: SafeResolutionResult<T> {
        mutating get {
            do {
                let value = try getValue()
                return .success(value)
            } catch let error as SafeDIError {
                return .failure(error)
            } catch {
                return .failure(.invalidConfiguration(reason: error.localizedDescription))
            }
        }
    }

    /// 안전한 Factory 값 가져오기
    public mutating func getValue() throws -> T {
        if let cached = cachedValue {
            return cached
        }

        guard let resolved = DependencyContainer.live[keyPath: keyPath] else {
            throw SafeDIError.factoryNotFound(keyPath: String(describing: keyPath))
        }

        self.cachedValue = resolved
        return resolved
    }
}

// MARK: - Migration Helpers

/// 기존 코드의 점진적 마이그레이션을 위한 헬퍼
public enum SafeInjectionMigration {

    /// 기존 @Inject를 @SafeInject로 마이그레이션하는 헬퍼
    public static func migrateInject<T>(_ result: SafeResolutionResult<T>) -> T? {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            #if DEBUG
            #logWarning("⚠️ [Migration] Injection failed: \(error.debugDescription)")
            #endif
            return nil
        }
    }

    /// 에러 로깅과 함께 마이그레이션
    public static func migrateInjectWithLogging<T>(
        _ result: SafeResolutionResult<T>,
        fallback: T? = nil
    ) -> T? {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            // 로깅 시스템에 에러 기록
            #logError("🚨 [SafeInjection] \(error.debugDescription)")

            // 복구 가능한 에러라면 fallback 사용
            if error.isRecoverable, let fallback = fallback {
                #logInfo("🔄 [SafeInjection] Using fallback value")
                return fallback
            }

            return nil
        }
    }
}

// MARK: - Convenience Extensions

public extension SafeResolutionResult {

    /// 값이 있는 경우에만 실행
    func onSuccess(_ action: (T) throws -> Void) rethrows {
        if case .success(let value) = self {
            try action(value)
        }
    }

    /// 에러가 있는 경우에만 실행
    func onFailure(_ action: (SafeDIError) throws -> Void) rethrows {
        if case .failure(let error) = self {
            try action(error)
        }
    }

    /// 값을 변환
    func map<U>(_ transform: (T) throws -> U) rethrows -> SafeResolutionResult<U> {
        switch self {
        case .success(let value):
            return .success(try transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// flatMap 변환
    func flatMap<U>(_ transform: (T) throws -> SafeResolutionResult<U>) rethrows -> SafeResolutionResult<U> {
        switch self {
        case .success(let value):
            return try transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}
