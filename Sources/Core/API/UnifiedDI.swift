//
//  UnifiedDI.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/19/25.
//

import Foundation
import LogMacro

// MARK: - Unified DI API

/// ## 개요
///
/// `UnifiedDI`는 모든 의존성 주입 API를 통합하는 단일 진입점입니다.
/// 기존의 분산된 API들(`DI`, `DependencyContainer.live`, `AutoRegister` 등)을
/// 하나의 일관성 있는 인터페이스로 통합하여 개발자 경험을 개선합니다.
///
/// ## 핵심 특징
///
/// ### 🎯 단일 진입점
/// - **일관된 API**: 모든 등록/해결 작업을 하나의 타입에서 수행
/// - **타입 안전성**: 컴파일 타임 타입 검증
/// - **명확한 의도**: 메서드 이름으로 동작 방식 명시
///
/// ### 🔄 통합된 등록 방법
/// - **팩토리 등록**: `register(_:factory:)`
/// - **KeyPath 등록**: `register(_:factory:)` - KeyPath 기반
/// - **조건부 등록**: `registerIf(_:condition:factory:fallback:)`
/// - **일괄 등록**: `registerMany { ... }`
///
/// ### 🛡️ 다양한 해결 전략
/// - **옵셔널 해결**: `resolve(_:)` - nil 가능
/// - **필수 해결**: `requireResolve(_:)` - 실패 시 fatalError
/// - **안전한 해결**: `resolveThrows(_:)` - 실패 시 throws
/// - **기본값 해결**: `resolve(_:default:)` - 항상 성공
/// - **성능 추적**: `resolveWithTracking(_:)` - 성능 측정 포함
///
/// ## 사용 예시
///
/// ### 기본 등록/해결
/// ```swift
/// // 타입 기반 등록
/// UnifiedDI.register(ServiceProtocol.self) { ServiceImpl() }
///
/// // KeyPath 기반 등록 (DI.register 스타일)
/// let repository = UnifiedDI.register(\.summaryPersistenceInterface) {
///     SummaryPersistenceRepositoryImpl()
/// }
///
/// // 해결
/// let service = UnifiedDI.resolve(ServiceProtocol.self)           // Optional
/// let database = UnifiedDI.requireResolve(DatabaseProtocol.self)  // Force unwrap
/// let logger = UnifiedDI.resolve(LoggerProtocol.self, default: ConsoleLogger())
/// ```
///
/// ### 일괄 등록
/// ```swift
/// UnifiedDI.registerMany {
///     Registration(NetworkService.self) { DefaultNetworkService() }
///     Registration(UserRepository.self) { UserRepositoryImpl() }
///     Registration(AuthService.self, condition: isProduction) {
///         ProductionAuthService()
///     } fallback: {
///         MockAuthService()
///     }
/// }
/// ```
///
/// ## 마이그레이션 가이드
///
/// ### 기존 DI API에서
/// ```swift
/// // Before
/// DI.register(Service.self) { ServiceImpl() }
/// let service = DI.resolve(Service.self)
///
/// // After
/// UnifiedDI.register(Service.self) { ServiceImpl() }
/// let service = UnifiedDI.resolve(Service.self)
/// ```
///
/// ### 기존 DependencyContainer에서
/// ```swift
/// // Before
/// DependencyContainer.live.register(Service.self, build: { ServiceImpl() })
/// let service = DependencyContainer.live.resolve(Service.self)
///
/// // After
/// UnifiedDI.register(Service.self) { ServiceImpl() }
/// let service = UnifiedDI.resolve(Service.self)
/// ```
public enum UnifiedDI {

    // MARK: - Core Registration APIs

    /// 팩토리 패턴으로 의존성을 등록합니다
    ///
    /// 이 메서드는 지연 생성 패턴을 사용하여 실제 `resolve` 호출 시에만
    /// 팩토리 클로저가 실행됩니다. 매번 새로운 인스턴스가 생성됩니다.
    ///
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: 등록 해제 핸들러 (호출하면 등록 해제)
    ///
    /// ### 사용 예시:
    /// ```swift
    /// let releaseHandler = UnifiedDI.register(NetworkService.self) {
    ///     DefaultNetworkService()
    /// }
    /// // 나중에 해제
    /// releaseHandler()
    /// ```
    @discardableResult
    public static func register<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> @Sendable () -> Void {
        return DependencyContainer.live.register(type, build: factory)
    }

    /// KeyPath를 사용하여 의존성을 등록하고 인스턴스를 반환합니다 (DI.register 스타일)
    ///
    /// DependencyContainer의 KeyPath를 사용하여 타입 안전한 방식으로
    /// 의존성을 등록하고 동시에 생성된 인스턴스를 반환합니다.
    /// 기존 `DI.register(\.keyPath)` 스타일과 호환되면서 더 편리합니다.
    ///
    /// - Parameters:
    ///   - keyPath: DependencyContainer 내의 KeyPath
    ///   - factory: 인스턴스를 생성하는 팩토리 클로저
    /// - Returns: 생성된 인스턴스
    ///
    /// ### 사용 예시:
    /// ```swift
    /// let repository = UnifiedDI.register(\.summaryPersistenceInterface) {
    ///     SummaryPersistenceRepositoryImpl()
    /// }
    /// return SummaryPersistenceUseCaseImpl(repository: repository)
    ///
    /// let service = UnifiedDI.register(\.userService) {
    ///     UserServiceImpl()
    /// }
    /// ```
    public static func register<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T
    ) -> T where T: Sendable {
        let instance = factory()
        DependencyContainer.live.register(T.self, instance: instance)
        return instance
    }



    /// 조건에 따라 다른 구현체를 등록합니다
    ///
    /// 런타임 조건에 따라 서로 다른 팩토리를 사용하여 의존성을 등록합니다.
    /// A/B 테스트, 환경별 분기, 피처 플래그 등에 유용합니다.
    ///
    /// - Parameters:
    ///   - type: 등록할 타입
    ///   - condition: 등록 조건 (true/false)
    ///   - factory: 조건이 true일 때 사용할 팩토리
    ///   - fallback: 조건이 false일 때 사용할 팩토리
    /// - Returns: 등록 해제 핸들러
    ///
    /// ### 사용 예시:
    /// ```swift
    /// UnifiedDI.registerIf(
    ///     AnalyticsService.self,
    ///     condition: isProduction,
    ///     factory: { FirebaseAnalytics() },
    ///     fallback: { MockAnalytics() }
    /// )
    /// ```
    @discardableResult
    public static func registerIf<T>(
        _ type: T.Type,
        condition: Bool,
        factory: @escaping @Sendable () -> T,
        fallback: @escaping @Sendable () -> T
    ) -> @Sendable () -> Void {
        if condition {
            return register(type, factory: factory)
        } else {
            return register(type, factory: fallback)
        }
    }

    // MARK: - Core Resolution APIs

    /// 등록된 의존성을 해결합니다 (옵셔널 반환)
    ///
    /// 가장 안전한 해결 방법으로, 의존성이 등록되지 않은 경우 nil을 반환합니다.
    /// 크래시 없이 안전하게 처리할 수 있습니다.
    ///
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스 (없으면 nil)
    ///
    /// ### 사용 예시:
    /// ```swift
    /// if let service = UnifiedDI.resolve(NetworkService.self) {
    ///     // 서비스 사용
    /// } else {
    ///     // 대체 로직 수행
    /// }
    /// ```
    public static func resolve<T>(_ type: T.Type) -> T? {
        return DependencyContainer.live.resolve(type)
    }

    /// KeyPath를 사용하여 등록된 의존성을 해결합니다 (옵셔널 반환)
    ///
    /// KeyPath 기반으로 의존성을 안전하게 해결합니다.
    /// 의존성이 등록되지 않은 경우 nil을 반환합니다.
    ///
    /// - Parameter keyPath: DependencyContainer 내의 KeyPath
    /// - Returns: 해결된 인스턴스 (없으면 nil)
    ///
    /// ### 사용 예시:
    /// ```swift
    /// if let repository = UnifiedDI.resolve(\.summaryPersistenceInterface) {
    ///     // 리포지토리 사용
    /// } else {
    ///     // 대체 로직 수행
    /// }
    /// ```
    public static func resolve<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> T? {
        return DependencyContainer.live.resolve(T.self)
    }

    /// 필수 의존성을 해결합니다 (실패 시 fatalError)
    ///
    /// 의존성이 반드시 등록되어 있어야 하는 경우 사용합니다.
    /// 등록되지 않은 경우 상세한 디버깅 정보와 함께 앱이 종료됩니다.
    ///
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스 (항상 성공)
    ///
    /// ### ⚠️ 주의사항:
    /// 프로덕션 코드에서는 `resolveThrows`를 사용하는 것을 권장합니다.
    ///
    /// ### 사용 예시:
    /// ```swift
    /// let database = UnifiedDI.requireResolve(DatabaseProtocol.self)
    /// // database는 항상 유효한 인스턴스
    /// ```
    public static func requireResolve<T>(_ type: T.Type) -> T {
        guard let resolved = DependencyContainer.live.resolve(type) else {
            let typeName = String(describing: type)
            fatalError("""
            🚨 [UnifiedDI] Required dependency not found!

            Type: \(typeName)

            💡 Fix by registering the dependency:
               UnifiedDI.register(\(typeName).self) { YourImplementation() }

            🔍 Make sure registration happens before resolution.
            """)
        }
        return resolved
    }

    /// KeyPath를 사용하여 필수 의존성을 해결합니다 (실패 시 fatalError)
    ///
    /// KeyPath 기반으로 의존성이 반드시 등록되어 있어야 하는 경우 사용합니다.
    /// 등록되지 않은 경우 상세한 디버깅 정보와 함께 앱이 종료됩니다.
    ///
    /// - Parameter keyPath: DependencyContainer 내의 KeyPath
    /// - Returns: 해결된 인스턴스 (항상 성공)
    ///
    /// ### 사용 예시:
    /// ```swift
    /// let repository = UnifiedDI.requireResolve(\.summaryPersistenceInterface)
    /// // repository는 항상 유효한 인스턴스
    /// ```
    public static func requireResolve<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> T {
        guard let resolved = DependencyContainer.live.resolve(T.self) else {
            let keyPathString = String(describing: keyPath)
            let typeName = String(describing: T.self)
            fatalError("""
            🚨 [UnifiedDI] Required dependency not found!

            KeyPath: \(keyPathString)
            Type: \(typeName)

            💡 Fix by registering the dependency:
               UnifiedDI.register(\(keyPathString)) { YourImplementation() }

            🔍 Make sure registration happens before resolution.
            """)
        }
        return resolved
    }

    /// 등록된 의존성을 해결하고 실패 시 throws
    ///
    /// 에러 처리가 가능한 안전한 해결 방법입니다.
    /// 프로덕션 환경에서 권장되는 패턴입니다.
    ///
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스
    /// - Throws: `DIError.dependencyNotFound`
    ///
    /// ### 사용 예시:
    /// ```swift
    /// do {
    ///     let service = try UnifiedDI.resolveThrows(NetworkService.self)
    ///     // 서비스 사용
    /// } catch {
    ///     // 에러 처리
    ///     #logDebug("Service not available: \(error)")
    /// }
    /// ```
    public static func resolveThrows<T>(_ type: T.Type) throws -> T {
        if let resolved = DependencyContainer.live.resolve(type) {
            return resolved
        } else {
            throw DIError.dependencyNotFound(type, hint: "Call UnifiedDI.register(\(type).self) { ... } first")
        }
    }

    /// 등록된 의존성을 해결하거나 기본값을 반환합니다
    ///
    /// 의존성이 없어도 항상 성공하는 안전한 해결 방법입니다.
    /// 기본 구현체나 Mock 객체를 제공할 때 유용합니다.
    ///
    /// - Parameters:
    ///   - type: 해결할 타입
    ///   - defaultValue: 해결 실패 시 사용할 기본값
    /// - Returns: 해결된 인스턴스 또는 기본값
    ///
    /// ### 사용 예시:
    /// ```swift
    /// let logger = UnifiedDI.resolve(LoggerProtocol.self, default: ConsoleLogger())
    /// // logger는 항상 유효한 인스턴스 (등록된 것 또는 ConsoleLogger)
    /// ```
    public static func resolve<T>(_ type: T.Type, default defaultValue: @autoclosure () -> T) -> T {
        return DependencyContainer.live.resolve(type) ?? defaultValue()
    }

    // MARK: - Performance APIs

    /// 성능 추적과 함께 의존성을 해결합니다
    ///
    /// 해결 과정의 성능을 측정하고 통계를 수집합니다.
    /// 디버그 빌드에서만 실제 측정이 수행되며, 릴리즈 빌드에서는 일반 resolve와 동일합니다.
    ///
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스 (없으면 nil)
    ///
    /// ### 사용 예시:
    /// ```swift
    /// let service = UnifiedDI.resolveWithTracking(NetworkService.self)
    /// // 성능 통계가 자동으로 수집됨
    /// ```
    public static func resolveWithTracking<T>(_ type: T.Type) -> T? {
        let token = SimplePerformanceOptimizer.startResolution(type)
        defer { SimplePerformanceOptimizer.endResolution(token) }

        return DependencyContainer.live.resolve(type)
    }

    /// 자주 사용되는 타입으로 표시하여 성능을 최적화합니다
    ///
    /// 특정 타입을 자주 사용되는 타입으로 등록하면
    /// 해당 타입의 해결 성능이 최적화됩니다.
    ///
    /// - Parameter type: 최적화할 타입
    ///
    /// ### 사용 예시:
    /// ```swift
    /// await UnifiedDI.markAsFrequentlyUsed(UserService.self)
    /// await UnifiedDI.markAsFrequentlyUsed(NetworkService.self)
    /// ```
    @MainActor
    public static func markAsFrequentlyUsed<T>(_ type: T.Type) {
        SimplePerformanceOptimizer.markAsFrequentlyUsed(type)
    }

    /// 성능 최적화를 활성화합니다
    ///
    /// 전체 DI 시스템의 성능 최적화를 활성화합니다.
    /// 앱 시작 시 한 번 호출하는 것을 권장합니다.
    ///
    /// ### 사용 예시:
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     init() {
    ///         Task { @MainActor in
    ///             await UnifiedDI.enablePerformanceOptimization()
    ///         }
    ///     }
    /// }
    /// ```
    @MainActor
    public static func enablePerformanceOptimization() {
        SimplePerformanceOptimizer.enableOptimization()

        #if DEBUG
        #logDebug("⚡ [UnifiedDI] Performance optimization enabled")
        #endif
    }

    /// 현재 성능 통계를 반환합니다
    ///
    /// DI 시스템의 성능 통계 정보를 가져옵니다.
    /// 디버그 빌드에서만 실제 데이터가 제공됩니다.
    ///
    /// - Returns: 성능 통계 정보
    ///
    /// ### 사용 예시:
    /// ```swift
    /// let stats = await UnifiedDI.getPerformanceStats()
    /// #logDebug(stats.summary)
    /// ```
    @MainActor
    public static func getPerformanceStats() -> SimplePerformanceOptimizer.PerformanceStats {
        return SimplePerformanceOptimizer.getStats()
    }

    // MARK: - Batch Registration APIs

    /// 여러 의존성을 한번에 등록합니다
    ///
    /// Result Builder를 사용한 DSL로 여러 의존성을 깔끔하게 등록할 수 있습니다.
    /// 앱 시작 시 초기화 코드에서 사용하기 적합합니다.
    ///
    /// - Parameter registrations: 등록할 의존성 목록
    ///
    /// ### 사용 예시:
    /// ```swift
    /// UnifiedDI.registerMany {
    ///     Registration(NetworkService.self) { DefaultNetworkService() }
    ///     Registration(UserRepository.self) { UserRepositoryImpl() }
    ///     Registration(LoggerProtocol.self, default: ConsoleLogger())
    /// }
    /// ```
    public static func registerMany(@UnifiedRegistrationBuilder _ registrations: () -> [UnifiedRegistration]) {
        let items = registrations()
        for registration in items {
            registration.register()
        }
    }

    // MARK: - Management APIs

    /// 등록된 의존성을 해제합니다
    ///
    /// 특정 타입의 의존성을 컨테이너에서 제거합니다.
    /// 테스트나 메모리 정리 시 사용합니다.
    ///
    /// - Parameter type: 해제할 타입
    ///
    /// ### 사용 예시:
    /// ```swift
    /// UnifiedDI.release(NetworkService.self)
    /// // 이후 resolve 시 nil 반환
    /// ```
    public static func release<T>(_ type: T.Type) {
        DependencyContainer.live.release(type)
    }

    /// 모든 등록된 의존성을 해제합니다
    ///
    /// 주로 테스트 환경에서 각 테스트 간 격리를 위해 사용합니다.
    /// 프로덕션에서는 사용을 권장하지 않습니다.
    ///
    /// ### ⚠️ 주의사항:
    /// 메인 스레드에서만 호출해야 합니다.
    ///
    /// ### 사용 예시:
    /// ```swift
    /// // 테스트 setUp에서
    /// override func setUp() {
    ///     super.setUp()
    ///     UnifiedDI.releaseAll()
    /// }
    /// ```
    @MainActor
    public static func releaseAll() {
        DependencyContainer.live = DependencyContainer()

        #if DEBUG
        #logDebug("🧹 [UnifiedDI] All registrations released")
        #endif
    }
}

// MARK: - Registration Builder

/// 일괄 등록을 위한 Result Builder
@resultBuilder
public struct UnifiedRegistrationBuilder {
    public static func buildBlock(_ components: UnifiedRegistration...) -> [UnifiedRegistration] {
        return components
    }

    public static func buildArray(_ components: [UnifiedRegistration]) -> [UnifiedRegistration] {
        return components
    }

    public static func buildOptional(_ component: UnifiedRegistration?) -> [UnifiedRegistration] {
        return component.map { [$0] } ?? []
    }

    public static func buildEither(first component: UnifiedRegistration) -> [UnifiedRegistration] {
        return [component]
    }

    public static func buildEither(second component: UnifiedRegistration) -> [UnifiedRegistration] {
        return [component]
    }
}

// MARK: - Registration Item

/// 일괄 등록을 위한 등록 아이템
public struct UnifiedRegistration {
    private let registerAction: () -> Void

    /// 팩토리 기반 등록
    public init<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        self.registerAction = {
            UnifiedDI.register(type, factory: factory)
        }
    }

    /// 기본값 포함 등록
    public init<T>(_ type: T.Type, default defaultValue: T) where T: Sendable {
        self.registerAction = {
            DependencyContainer.live.register(type, instance: defaultValue)
        }
    }

    /// 조건부 등록
    public init<T>(
        _ type: T.Type,
        condition: Bool,
        factory: @escaping @Sendable () -> T,
        fallback: @escaping @Sendable () -> T
    ) {
        self.registerAction = {
            UnifiedDI.registerIf(type, condition: condition, factory: factory, fallback: fallback)
        }
    }

    /// 등록 실행
    internal func register() {
        registerAction()
    }
}

// MARK: - Convenience Extensions

public extension UnifiedRegistration {
    // Duplicate initializer removed to avoid conflicts
}

/// 등록 클로저를 위한 Result Builder
@resultBuilder
public struct RegistrationBuilder {
    public static func buildBlock<T>(_ component: T) -> T {
        return component
    }
}

// MARK: - Legacy Compatibility

/// 기존 DI API와의 호환성을 위한 별칭
/// 향후 deprecation 예정
public typealias SimplifiedDI = UnifiedDI

// MARK: - Type Aliases for Migration

// Note: Legacy compatibility aliases removed to avoid conflicts with SimplifiedAPI.swift
