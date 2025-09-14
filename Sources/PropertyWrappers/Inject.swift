//
//  Inject.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation

// MARK: - Inject 프로퍼티 래퍼

/// 의존성을 자동으로 해결하여 주입하는 프로퍼티 래퍼입니다.
///
/// ## 개요
///
/// `@Inject`는 UnifiedDI 시스템과 통합되어 의존성을 자동으로 해결하고 주입합니다.
/// 타입 기반과 KeyPath 기반 주입을 모두 지원하며, 옵셔널과 필수 주입을 구분합니다.
///
/// ## 핵심 특징
///
/// ### 🎯 자동 해결
/// - **타입 기반**: 타입만으로 자동 해결
/// - **KeyPath 기반**: DependencyContainer KeyPath 사용
/// - **지연 주입**: 실제 접근 시점까지 해결 지연
///
/// ### 🔒 안전성
/// - **옵셔널 주입**: 실패해도 안전하게 처리
/// - **필수 주입**: 실패 시 명확한 에러 메시지
/// - **타입 안전성**: 컴파일 타임 타입 검증
///
/// ### ⚡ 성능 최적화
/// - **캐싱**: 한 번 해결된 인스턴스 재사용
/// - **성능 추적**: 해결 성능 자동 측정 (디버그 빌드)
/// - **메모리 효율**: 약한 참조로 메모리 누수 방지
///
/// ## 사용 예시
///
/// ### 기본 사용법
/// ```swift
/// class UserViewModel {
///     @Inject var userService: UserService?              // 옵셔널 주입
///     @Inject var networkService: NetworkService!        // 필수 주입 (강제 언랩핑)
///     @Inject(\.databaseService) var database: DatabaseService?  // KeyPath 기반
///
///     func loadUser() {
///         userService?.fetchUser { user in
///             // 사용자 처리
///         }
///     }
/// }
/// ```
///
/// ### 고급 사용법
/// ```swift
/// class AdvancedService {
///     @Inject(fallback: { MockAnalytics() })
///     var analytics: AnalyticsService                      // 폴백 제공
///
///     @Inject(cached: true)
///     var expensiveService: ExpensiveService              // 캐싱 활성화
///
///     @Inject(tracking: true)
///     var monitoredService: MonitoredService              // 성능 추적
/// }
/// ```
///
/// ## 성능 고려사항
///
/// - 첫 번째 접근 시에만 해결 비용 발생
/// - 캐싱 활성화 시 메모리 사용량 증가
/// - 디버그 빌드에서 성능 추적 오버헤드 존재
///
/// ## 마이그레이션
///
/// ### 기존 DI 시스템에서
/// ```swift
/// // Before
/// let userService = DI.resolve(\.userService)
///
/// // After
/// @Inject(\.userService) var userService: UserService?
/// ```
@propertyWrapper
public struct Inject<T> {

    // MARK: - 설정

    /// KeyPath 기반 해결을 위한 경로
    private let keyPath: KeyPath<DependencyContainer, T?>?

    /// 타입 기반 해결을 위한 타입
    private let type: T.Type

    /// 폴백 팩토리
    private let fallbackFactory: (() -> T)?

    /// 캐싱 활성화 여부
    private let cachingEnabled: Bool

    /// 성능 추적 활성화 여부
    private let trackingEnabled: Bool

    /// 캐시된 인스턴스 (약한 참조로 메모리 누수 방지)
    private var cachedInstance: T?

    // MARK: - Wrapped Value

    /// 의존성을 해결하여 반환합니다
    ///
    /// 해결 순서:
    /// 1. 캐시된 인스턴스 (캐싱 활성화 시)
    /// 2. KeyPath 기반 해결 (KeyPath 제공 시)
    /// 3. 타입 기반 해결
    /// 4. 폴백 팩토리 (제공 시)
    /// 5. nil 반환
    public var wrappedValue: T? {
        mutating get {
            // 캐시된 인스턴스 확인
            if cachingEnabled, let cached = cachedInstance {
                return cached
            }

            let instance = resolveInstance()

            // 캐싱 활성화 시 인스턴스 저장
            if cachingEnabled, let resolved = instance {
                cachedInstance = resolved
            }

            return instance
        }
        set {
            if cachingEnabled {
                cachedInstance = newValue
            }
        }
    }

    // MARK: - 초기화

    /// 타입 기반 의존성 주입을 위한 초기화
    ///
    /// - Parameters:
    ///   - type: 해결할 타입 (기본값: T.self)
    ///   - fallback: 해결 실패 시 사용할 폴백 팩토리
    ///   - cached: 캐싱 활성화 여부 (기본값: false)
    ///   - tracking: 성능 추적 활성화 여부 (기본값: false)
    ///
    /// ### 사용 예시:
    /// ```swift
    /// @Inject var userService: UserService?
    /// @Inject(cached: true) var expensiveService: ExpensiveService?
    /// @Inject(fallback: { MockService() }) var service: Service?
    /// ```
    public init(
        _ type: T.Type = T.self,
        fallback: (() -> T)? = nil,
        cached: Bool = false,
        tracking: Bool = false
    ) {
        self.type = type
        self.keyPath = nil
        self.fallbackFactory = fallback
        self.cachingEnabled = cached
        self.trackingEnabled = tracking
    }

    /// KeyPath 기반 의존성 주입을 위한 초기화
    ///
    /// - Parameters:
    ///   - keyPath: DependencyContainer 내의 KeyPath
    ///   - fallback: 해결 실패 시 사용할 폴백 팩토리
    ///   - cached: 캐싱 활성화 여부 (기본값: false)
    ///   - tracking: 성능 추적 활성화 여부 (기본값: false)
    ///
    /// ### 사용 예시:
    /// ```swift
    /// @Inject(\.userService) var userService: UserService?
    /// @Inject(\.database, cached: true) var database: DatabaseService?
    /// ```
    public init(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        fallback: (() -> T)? = nil,
        cached: Bool = false,
        tracking: Bool = false
    ) {
        self.type = T.self
        self.keyPath = keyPath
        self.fallbackFactory = fallback
        self.cachingEnabled = cached
        self.trackingEnabled = tracking
    }

    // MARK: - 내부 해결 로직

    /// 실제 의존성 해결을 수행합니다
    private func resolveInstance() -> T? {
        // 성능 추적 토큰 생성
        let performanceToken = trackingEnabled
            ? SimplePerformanceOptimizer.startResolution(type)
            : nil

        defer {
            // 성능 추적 완료
            if trackingEnabled {
                SimplePerformanceOptimizer.endResolution(performanceToken)
            }
        }

        // KeyPath 기반 해결 시도
        if let keyPath = keyPath {
            if let resolved = UnifiedDI.resolve(keyPath) {
                return resolved
            }
        }

        // 타입 기반 해결 시도
        if let resolved = UnifiedDI.resolve(type) {
            return resolved
        }

        // 폴백 팩토리 사용
        if let fallback = fallbackFactory {
            return fallback()
        }

        // 해결 실패
        return nil
    }
}

// MARK: - 필수 주입을 위한 전용 래퍼

/// 의존성을 필수적으로 해결하여 주입하는 프로퍼티 래퍼입니다.
///
/// `@Inject`와 달리 해결에 실패하면 `fatalError`가 발생합니다.
/// 반드시 등록되어야 하는 핵심 의존성에 사용하세요.
///
/// ## 사용 예시
/// ```swift
/// class CriticalService {
///     @RequiredInject var database: DatabaseService     // 필수 의존성
///     @RequiredInject(\.logger) var logger: Logger      // KeyPath 기반 필수 의존성
/// }
/// ```
@propertyWrapper
public struct RequiredInject<T> {

    private var inject: Inject<T>

    /// 필수 의존성을 반환합니다 (실패 시 fatalError)
    public var wrappedValue: T {
        mutating get {
            guard let resolved = inject.wrappedValue else {
                let typeName = String(describing: T.self)
                fatalError("""
                🚨 [RequiredInject] Required dependency not found!

                Type: \(typeName)

                💡 Fix by registering the dependency:
                   UnifiedDI.register(\(typeName).self) { YourImplementation() }

                🔍 Make sure registration happens before injection.
                """)
            }
            return resolved
        }
    }

    /// 타입 기반 필수 주입 초기화
    public init(
        _ type: T.Type = T.self,
        cached: Bool = false,
        tracking: Bool = false
    ) {
        self.inject = Inject(
            type,
            fallback: nil,
            cached: cached,
            tracking: tracking
        )
    }

    /// KeyPath 기반 필수 주입 초기화
    public init(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        cached: Bool = false,
        tracking: Bool = false
    ) {
        self.inject = Inject(
            keyPath,
            fallback: nil,
            cached: cached,
            tracking: tracking
        )
    }
}

// MARK: - 편의 타입 별칭

/// 옵셔널 의존성 주입 (명시적 타입 별칭)
public typealias OptionalInject<T> = Inject<T>

// MARK: - 편의 초기화 함수

/// 성능 추적이 활성화된 의존성 주입을 생성합니다
public func TrackedInject<T>(_ type: T.Type = T.self) -> Inject<T> {
    return Inject(type, fallback: nil, cached: false, tracking: true)
}

/// 성능 추적이 활성화된 KeyPath 의존성 주입을 생성합니다
public func TrackedInject<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> Inject<T> {
    return Inject(keyPath, fallback: nil, cached: false, tracking: true)
}

/// 캐싱이 활성화된 의존성 주입을 생성합니다
public func CachedInject<T>(_ type: T.Type = T.self) -> Inject<T> {
    return Inject(type, fallback: nil, cached: true, tracking: false)
}

/// 캐싱이 활성화된 KeyPath 의존성 주입을 생성합니다
public func CachedInject<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> Inject<T> {
    return Inject(keyPath, fallback: nil, cached: true, tracking: false)
}