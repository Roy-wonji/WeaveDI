//
//  InjectExtensions.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - 고급 Injection 확장

/// 조건부 의존성 주입을 위한 프로퍼티 래퍼입니다.
///
/// ## 개요
///
/// `@ConditionalInject`는 런타임 조건에 따라 서로 다른 의존성을 주입할 수 있습니다.
/// 환경별 구성, A/B 테스트, 기능 플래그 등에 유용합니다.
///
/// ## 사용 예시
///
/// ```swift
/// class AnalyticsService {
///     @ConditionalInject(
///         condition: { ProcessInfo.processInfo.environment["ANALYTICS_ENABLED"] == "true" },
///         primary: \.realAnalytics,
///         fallback: \.mockAnalytics
///     )
///     var analytics: AnalyticsProtocol?
///
///     @ConditionalInject(
///         condition: { UserDefaults.standard.bool(forKey: "beta_features") },
///         primaryFactory: { BetaFeatureManager() },
///         fallbackFactory: { StandardFeatureManager() }
///     )
///     var featureManager: FeatureManagerProtocol?
/// }
/// ```
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
                if var primary = primaryInjection {
                    let result = primary.wrappedValue
                    primaryInjection = primary
                    return result
                } else if let factory = primaryFactory {
                    return factory()
                }
            }

            if var fallback = fallbackInjection {
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

    /// 혼합 조건부 주입 초기화 (Primary는 KeyPath, Fallback은 Factory)
    public init(
        condition: @escaping () -> Bool,
        primary: KeyPath<DependencyContainer, T?>,
        fallbackFactory: @escaping () -> T
    ) {
        self.condition = condition
        self.primaryInjection = Inject(primary)
        self.fallbackInjection = nil
        self.primaryFactory = nil
        self.fallbackFactory = fallbackFactory
    }
}

// MARK: - 다중 인스턴스 주입

/// 배열 형태의 다중 의존성 주입을 위한 프로퍼티 래퍼입니다.
///
/// ## 개요
///
/// `@MultiInject`는 같은 프로토콜을 구현하는 여러 구현체를 배열로 주입받을 수 있습니다.
/// 플러그인 시스템, 미들웨어 체인, 옵저버 패턴 등에 유용합니다.
///
/// ## 사용 예시
///
/// ```swift
/// class NotificationManager {
///     @MultiInject([\.emailNotifier, \.pushNotifier, \.smsNotifier])
///     var notifiers: [NotifierProtocol]
///
///     @MultiInject([
///         { EmailValidator() },
///         { PhoneValidator() },
///         { AddressValidator() }
///     ])
///     var validators: [ValidatorProtocol]
///
///     func sendNotification(_ message: String) {
///         notifiers.forEach { $0.send(message) }
///     }
/// }
/// ```
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

    /// 혼합 다중 주입 초기화 (KeyPath + Factory)
    public init(
        keyPaths: [KeyPath<DependencyContainer, T?>] = [],
        factories: [() -> T] = []
    ) {
        self.keyPaths = keyPaths
        self.factories = factories
    }
}

// MARK: - 비동기 주입

/// 비동기 의존성 주입을 위한 프로퍼티 래퍼입니다.
///
/// ## 개요
///
/// `@AsyncInject`는 비동기적으로 초기화되는 의존성을 안전하게 주입받을 수 있습니다.
/// 네트워크 기반 서비스, 데이터베이스 연결, 원격 구성 등에 유용합니다.
///
/// ## 사용 예시
///
/// ```swift
/// class DatabaseService {
///     @AsyncInject(\.databaseConnection, timeout: 5.0)
///     var connection: DatabaseConnection?
///
///     @AsyncInject {
///         await RemoteConfigService.shared.initialize()
///         return RemoteConfigService.shared
///     }
///     var remoteConfig: RemoteConfigService?
///
///     func connect() async {
///         guard let connection = await $connection.resolve() else {
///             throw DatabaseError.connectionFailed
///         }
///         // 연결 사용
///     }
/// }
/// ```
@propertyWrapper
public struct AsyncInject<T: Sendable> {

    private let keyPath: KeyPath<DependencyContainer, T?>?
    private let asyncFactory: (() async -> T)?
    private let timeout: TimeInterval
    private var cachedTask: Task<T?, Error>?

    /// 비동기 해결을 위한 projected value
    public var projectedValue: AsyncInject<T> {
        return self
    }

    /// 현재 동기적으로 사용 가능한 값 (nil - 비동기 해결 필요)
    public var wrappedValue: T? {
        // 비동기 해결이 필요하므로 항상 nil 반환
        // 실제 값은 resolve() 메서드를 통해 비동기적으로 획득
        return nil
    }

    /// KeyPath 기반 비동기 주입 초기화
    public init(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        timeout: TimeInterval = 10.0
    ) {
        self.keyPath = keyPath
        self.asyncFactory = nil
        self.timeout = timeout
        self.cachedTask = nil
    }

    /// Factory 기반 비동기 주입 초기화
    public init(
        timeout: TimeInterval = 10.0,
        factory: @escaping () async -> T
    ) {
        self.keyPath = nil
        self.asyncFactory = factory
        self.timeout = timeout
        self.cachedTask = nil
    }

    /// 비동기적으로 의존성 해결
    public func resolve() async -> T? {
        // KeyPath 기반 해결
        if let keyPath = keyPath {
            return DependencyContainer.live[keyPath: keyPath]
        }

        // Factory 기반 해결
        if let factory = asyncFactory {
            return await factory()
        }

        return nil
    }

    /// 해결 상태 확인 (간단한 캐시 확인)
    public var isResolving: Bool {
        return cachedTask != nil
    }

    /// 캐시된 Task 취소
    public mutating func cancel() {
        cachedTask?.cancel()
        cachedTask = nil
    }
}

// MARK: - 에러 타입

public enum AsyncInjectError: Error, LocalizedError {
    case timeout
    case resolutionFailed

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "비동기 의존성 해결이 시간 초과되었습니다"
        case .resolutionFailed:
            return "비동기 의존성 해결에 실패했습니다"
        }
    }
}

// MARK: - 검증 및 진단

/// 의존성 주입 검증을 위한 프로퍼티 래퍼입니다.
///
/// ## 개요
///
/// `@ValidatedInject`는 주입된 의존성의 유효성을 검사하고 상세한 진단 정보를 제공합니다.
/// 개발 및 디버깅 단계에서 의존성 문제를 빠르게 파악할 수 있습니다.
///
/// ## 사용 예시
///
/// ```swift
/// class UserService {
///     @ValidatedInject(
///         \.userRepository,
///         validator: { repo in repo.isConnected },
///         errorMessage: "UserRepository가 데이터베이스에 연결되지 않았습니다"
///     )
///     var repository: UserRepositoryProtocol?
///
///     @ValidatedInject(
///         NetworkService.self,
///         validators: [
///             { $0.isReachable },
///             { $0.hasValidCredentials }
///         ]
///     )
///     var networkService: NetworkService?
/// }
/// ```
@propertyWrapper
public struct ValidatedInject<T> {

    private var baseInject: Inject<T>
    private let validators: [(T) -> Bool]
    private let errorMessages: [String]

    public var wrappedValue: T? {
        mutating get {
            guard let instance = baseInject.wrappedValue else {
                #if DEBUG
                print("🚨 [ValidatedInject] 의존성을 해결할 수 없습니다: \(T.self)")
                #endif
                return nil
            }

            // 모든 검증자 실행
            for (index, validator) in validators.enumerated() {
                if !validator(instance) {
                    let message = errorMessages.indices.contains(index)
                        ? errorMessages[index]
                        : "검증 \(index + 1) 실패"

                    #if DEBUG
                    print("❌ [ValidatedInject] 검증 실패 - \(T.self): \(message)")
                    #endif

                    return nil
                }
            }

            #if DEBUG
            print("✅ [ValidatedInject] 검증 성공 - \(T.self)")
            #endif

            return instance
        }
    }

    /// KeyPath 기반 검증 주입 초기화 (단일 검증자)
    public init(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        validator: @escaping (T) -> Bool,
        errorMessage: String = "검증 실패"
    ) {
        self.baseInject = Inject(keyPath)
        self.validators = [validator]
        self.errorMessages = [errorMessage]
    }

    /// KeyPath 기반 검증 주입 초기화 (다중 검증자)
    public init(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        validators: [(T) -> Bool],
        errorMessages: [String] = []
    ) {
        self.baseInject = Inject(keyPath)
        self.validators = validators
        self.errorMessages = errorMessages
    }

    /// 타입 기반 검증 주입 초기화 (단일 검증자)
    public init(
        _ type: T.Type,
        validator: @escaping (T) -> Bool,
        errorMessage: String = "검증 실패"
    ) {
        self.baseInject = Inject(type)
        self.validators = [validator]
        self.errorMessages = [errorMessage]
    }

    /// 타입 기반 검증 주입 초기화 (다중 검증자)
    public init(
        _ type: T.Type,
        validators: [(T) -> Bool],
        errorMessages: [String] = []
    ) {
        self.baseInject = Inject(type)
        self.validators = validators
        self.errorMessages = errorMessages
    }
}

// MARK: - 편의 확장

// MARK: - 편의 생성 함수

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

// MARK: - 레거시 호환성

/// 기존 @Inject 프로퍼티 래퍼의 편의 별칭들
public typealias InjectOptional<T> = Inject<T>
public typealias InjectRequired<T> = RequiredInject<T>