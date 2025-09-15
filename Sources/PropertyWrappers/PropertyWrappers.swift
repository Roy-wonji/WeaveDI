//
//  PropertyWrappers.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Core Property Wrappers

/// 옵셔널 의존성 주입을 위한 프로퍼티 래퍼
///
/// ## 개요
///
/// `@Inject`는 DiContainer의 핵심 프로퍼티 래퍼로, 의존성을 자동으로 주입받을 수 있습니다.
/// 변수 타입이 옵셔널이면 안전한 주입을, Non-optional이면 필수 주입을 수행합니다.
///
/// ## 사용 예시
///
/// ```swift
/// class UserService {
///     @Inject var repository: UserRepository?        // 옵셔널 주입
///     @Inject var logger: Logger                     // 필수 주입 (Non-optional)
///     @Inject(\.customService) var custom: CustomService?  // KeyPath 주입
/// }
/// ```
@propertyWrapper
public struct Inject<T> {
    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let type: T.Type?

    public var wrappedValue: T? {
        if let keyPath = keyPath {
            return DependencyContainer.live[keyPath: keyPath]
        }

        if let type = type {
            return DependencyContainer.live.resolve(type)
        }

        return nil
    }

    /// KeyPath 기반 주입 초기화
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        self.type = nil
    }

    /// 타입 기반 주입 초기화 (타입 추론)
    public init() {
        self.keyPath = nil
        self.type = T.self
    }

    /// 명시적 타입 기반 주입 초기화
    public init(_ type: T.Type) {
        self.keyPath = nil
        self.type = type
    }
}

/// Non-optional 타입을 위한 특별한 확장
extension Inject where T: AnyObject {
    public var wrappedValue: T {
        if let keyPath = keyPath {
            guard let resolved = DependencyContainer.live[keyPath: keyPath] else {
                fatalError("🚨 [Inject] Required dependency not found for keyPath \(keyPath)")
            }
            return resolved
        }

        if let type = type {
            guard let resolved = DependencyContainer.live.resolve(type) else {
                fatalError("🚨 [Inject] Required dependency not found: \(type)")
            }
            return resolved
        }

        fatalError("🚨 [Inject] Invalid configuration")
    }
}

/// 필수 의존성 주입을 위한 프로퍼티 래퍼
///
/// ## 개요
///
/// `@RequiredInject`는 의존성이 반드시 등록되어 있어야 하는 경우에 사용합니다.
/// 등록되지 않은 경우 명확한 에러 메시지와 함께 fatalError를 발생시킵니다.
///
/// ## 사용 예시
///
/// ```swift
/// class UserService {
///     @RequiredInject var database: Database
///     @RequiredInject(\.logger) var logger: Logger
/// }
/// ```
@propertyWrapper
public struct RequiredInject<T> {
    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let type: T.Type?

    public var wrappedValue: T {
        if let keyPath = keyPath {
            guard let resolved = DependencyContainer.live[keyPath: keyPath] else {
                let suggestion = "Register using: DI.register(\\.keyPath) { YourImplementation() }"
                fatalError("""
                🚨 [RequiredInject] Required dependency not found!

                KeyPath: \(keyPath)
                Type: \(T.self)

                💡 Fix by adding this to your app startup:
                   \(suggestion)

                🔍 Make sure you called this before accessing the @RequiredInject property.
                """)
            }
            return resolved
        }

        if let type = type {
            guard let resolved = DependencyContainer.live.resolve(type) else {
                let suggestion = "DI.register(\(type).self) { YourImplementation() }"
                fatalError("""
                🚨 [RequiredInject] Required dependency not found!

                Type: \(type)

                💡 Fix by adding this to your app startup:
                   \(suggestion)

                🔍 Make sure you called this before accessing the @RequiredInject property.
                """)
            }
            return resolved
        }

        fatalError("🚨 [RequiredInject] Invalid configuration")
    }

    /// KeyPath 기반 필수 주입 초기화
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        self.type = nil
    }

    /// 타입 기반 필수 주입 초기화 (타입 추론)
    public init() {
        self.keyPath = nil
        self.type = T.self
    }

    /// 명시적 타입 기반 필수 주입 초기화
    public init(_ type: T.Type) {
        self.keyPath = nil
        self.type = type
    }
}

// MARK: - Factory Property Wrappers

/// 팩토리 패턴 기반 의존성 주입을 위한 프로퍼티 래퍼
///
/// ## 개요
///
/// `@Factory`는 매번 새로운 인스턴스를 생성하는 팩토리 기반 주입을 제공합니다.
/// 상태를 공유하지 않는 독립적인 인스턴스가 필요한 경우에 유용합니다.
///
/// ## 사용 예시
///
/// ```swift
/// class ReportService {
///     @Factory var pdfGenerator: PDFGenerator          // 매번 새로운 인스턴스
///     @Factory(\.emailSender) var emailSender: EmailSender
/// }
/// ```
@propertyWrapper
public struct Factory<T> {
    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let factory: (() -> T)?

    public var wrappedValue: T {
        if let keyPath = keyPath {
            // KeyPath 방식은 등록된 팩토리를 매번 실행
            if let resolved = DependencyContainer.live[keyPath: keyPath] {
                return resolved
            } else {
                fatalError("🚨 [Factory] Factory not found for keyPath \(keyPath)")
            }
        }

        if let factory = factory {
            return factory()
        }

        fatalError("🚨 [Factory] Invalid configuration")
    }

    /// KeyPath 기반 팩토리 초기화
    public init(_ keyPath: KeyPath<DependencyContainer, T?>) {
        self.keyPath = keyPath
        self.factory = nil
    }

    /// 직접 팩토리 초기화
    public init(factory: @escaping () -> T) {
        self.keyPath = nil
        self.factory = factory
    }

    /// 타입 추론 팩토리 초기화
    public init() where T: DefaultConstructible {
        self.keyPath = nil
        self.factory = { T() }
    }
}

/// 기본 생성자를 가진 타입을 위한 프로토콜
public protocol DefaultConstructible {
    init()
}

/// 팩토리 값들을 관리하는 프로퍼티 래퍼
///
/// ## 개요
///
/// `@FactoryValues`는 여러 관련된 팩토리 값들을 함께 관리할 수 있습니다.
/// 설정 값, 상수, 환경별 값 등을 관리하는 데 유용합니다.
///
/// ## 사용 예시
///
/// ```swift
/// struct APIConfiguration {
///     @FactoryValues var values: APIValues
/// }
///
/// struct APIValues {
///     let baseURL: String
///     let timeout: TimeInterval
///     let retryCount: Int
/// }
/// ```
@propertyWrapper
public struct FactoryValues<T> {
    private let factory: () -> T
    private var cachedValue: T?
    private let shouldCache: Bool

    public var wrappedValue: T {
        mutating get {
            if shouldCache, let cached = cachedValue {
                return cached
            }

            let value = factory()
            if shouldCache {
                cachedValue = value
            }
            return value
        }
    }

    /// 캐싱 팩토리 값 초기화
    public init(cached: Bool = true, factory: @escaping () -> T) {
        self.factory = factory
        self.shouldCache = cached
        self.cachedValue = nil
    }

    /// 즉시 실행 팩토리 값 초기화
    public init(immediate factory: @escaping () -> T) {
        self.factory = factory
        self.shouldCache = true
        self.cachedValue = factory()
    }
}

// MARK: - Advanced Property Wrappers

/// 조건부 의존성 주입을 위한 프로퍼티 래퍼
@propertyWrapper
public struct ConditionalInject<T> {
    private let condition: () -> Bool
    private var primaryInjection: Inject<T>?
    private var fallbackInjection: Inject<T>?
    private let primaryFactory: (() -> T)?
    private let fallbackFactory: (() -> T)?

    public var wrappedValue: T? {
        mutating get {
            if condition() {
              if let primary = primaryInjection {
                    let result = primary.wrappedValue
                    primaryInjection = primary
                    return result
                } else if let factory = primaryFactory {
                    return factory()
                }
            }

          if let fallback = fallbackInjection {
                let result = fallback.wrappedValue
                fallbackInjection = fallback
                return result
            } else if let factory = fallbackFactory {
                return factory()
            }

            return nil
        }
    }

    /// KeyPath 기반 조건부 주입 초기화
    public init(
        condition: @escaping () -> Bool,
        primary: KeyPath<DependencyContainer, T?>,
        fallback: KeyPath<DependencyContainer, T?>
    ) {
        self.condition = condition
        self.primaryInjection = Inject(primary)
        self.fallbackInjection = Inject(fallback)
        self.primaryFactory = nil
        self.fallbackFactory = nil
    }

    /// Factory 기반 조건부 주입 초기화
    public init(
        condition: @escaping () -> Bool,
        primaryFactory: @escaping () -> T,
        fallbackFactory: @escaping () -> T
    ) {
        self.condition = condition
        self.primaryInjection = nil
        self.fallbackInjection = nil
        self.primaryFactory = primaryFactory
        self.fallbackFactory = fallbackFactory
    }
}

/// 다중 의존성 주입을 위한 프로퍼티 래퍼
@propertyWrapper
public struct MultiInject<T> {
    private let keyPaths: [KeyPath<DependencyContainer, T?>]
    private let factories: [() -> T]

    public var wrappedValue: [T] {
        var results: [T] = []

        // KeyPath 기반 인스턴스들 수집
        for keyPath in keyPaths {
            if let instance = DependencyContainer.live[keyPath: keyPath] {
                results.append(instance)
            }
        }

        // Factory 기반 인스턴스들 생성
        for factory in factories {
            results.append(factory())
        }

        return results
    }

    /// KeyPath 배열 기반 다중 주입 초기화
    public init(_ keyPaths: [KeyPath<DependencyContainer, T?>]) {
        self.keyPaths = keyPaths
        self.factories = []
    }

    /// Factory 배열 기반 다중 주입 초기화
    public init(_ factories: [() -> T]) {
        self.keyPaths = []
        self.factories = factories
    }

    /// 혼합 다중 주입 초기화
    public init(
        keyPaths: [KeyPath<DependencyContainer, T?>] = [],
        factories: [() -> T] = []
    ) {
        self.keyPaths = keyPaths
        self.factories = factories
    }
}

// MARK: - Required Dependency Register

/// 의존성 등록과 검증을 위한 프로퍼티 래퍼
///
/// ## 개요
///
/// `@RequiredDependencyRegister`는 특정 의존성이 반드시 등록되어야 하는
/// 컴포넌트에서 사용됩니다. 컴파일 타임에 의존성 요구사항을 명시하고
/// 런타임에 검증을 수행합니다.
@propertyWrapper
public struct RequiredDependencyRegister<T> {
    private let keyPath: KeyPath<DependencyContainer, T?>
    private let errorMessage: String

    public var wrappedValue: T {
        guard let resolved = DependencyContainer.live[keyPath: keyPath] else {
            fatalError("""
            🚨 [RequiredDependencyRegister] \(errorMessage)

            KeyPath: \(keyPath)
            Type: \(T.self)

            💡 This dependency must be registered before using this component.
            """)
        }
        return resolved
    }

    public init(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        errorMessage: String = "Required dependency not registered"
    ) {
        self.keyPath = keyPath
        self.errorMessage = errorMessage
    }
}

// MARK: - Convenience Functions

/// 환경 변수 기반 조건부 주입을 생성합니다
public func ConditionalInjectFromEnvironment<T>(
    _ key: String,
    expectedValue: String,
    primary: KeyPath<DependencyContainer, T?>,
    fallback: KeyPath<DependencyContainer, T?>
) -> ConditionalInject<T> {
    return ConditionalInject(
        condition: {
            ProcessInfo.processInfo.environment[key] == expectedValue
        },
        primary: primary,
        fallback: fallback
    )
}

/// UserDefaults 기반 조건부 주입을 생성합니다
public func ConditionalInjectFromUserDefault<T>(
    _ key: String,
    primary: KeyPath<DependencyContainer, T?>,
    fallback: KeyPath<DependencyContainer, T?>
) -> ConditionalInject<T> {
    return ConditionalInject(
        condition: {
            UserDefaults.standard.bool(forKey: key)
        },
        primary: primary,
        fallback: fallback
    )
}

// MARK: - Type Aliases

/// 레거시 호환성을 위한 타입 별칭들
public typealias InjectOptional<T> = Inject<T>
public typealias InjectRequired<T> = RequiredInject<T>
