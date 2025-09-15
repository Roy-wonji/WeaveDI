//
//  DI.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - DI (Simplified API)

/// 단순화된 의존성 주입 API
///
/// ## 개요
///
/// `DI`는 DiContainer의 단순화된 API로, 가장 일반적인 의존성 주입 작업에 집중합니다.
/// 복잡한 기능이 필요한 경우 `UnifiedDI`를 사용하세요.
///
/// ## 핵심 기능
///
/// - 기본 등록/해결
/// - KeyPath 기반 등록
/// - 조건부 등록
/// - 관리 및 내성 API
///
/// ## 사용 예시
///
/// ```swift
/// // 등록
/// DI.register(UserService.self) { UserServiceImpl() }
///
/// // 해결
/// let service = DI.resolve(UserService.self)
///
/// // KeyPath 등록
/// let instance = DI.register(\.userService) { UserServiceImpl() }
/// ```
public enum DI {

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
    ) -> @Sendable () -> Void {
        return DependencyContainer.live.register(type, build: factory)
    }

    /// KeyPath 기반으로 의존성을 등록하고 생성된 인스턴스를 즉시 반환합니다
    /// - Parameters:
    ///   - keyPath: `DependencyContainer` 내의 의존성 위치
    ///   - factory: 인스턴스를 생성하는 클로저
    /// - Returns: 생성된 인스턴스 (동시에 DI 컨테이너에 등록됨)
    @discardableResult
    static func register<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T
    ) -> T where T: Sendable {
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
    ) -> @Sendable () -> Void {
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
    ) -> T where T: Sendable {
        return condition ? register(keyPath, factory: factory) : register(keyPath, factory: fallback)
    }

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

    // MARK: - Management

    /// 등록된 의존성을 해제합니다
    /// - Parameter type: 해제할 타입
    static func release<T>(_ type: T.Type) {
        DependencyContainer.live.release(type)
    }

    /// 모든 등록된 의존성을 해제합니다 (테스트 용도)
    /// - Warning: 메인 스레드에서만 호출하세요
    @MainActor
    static func releaseAll() {
        DependencyContainer.live = DependencyContainer()

        #if DEBUG
        print("🧹 [DI] All registrations released - container reset")
        #endif
    }

    /// 비동기 환경에서 모든 등록을 해제합니다
    static func releaseAllAsync() async {
        await DIActorGlobalAPI.releaseAll()
    }

    // MARK: - Introspection

    /// 타입 기반 등록 여부 확인
    static func isRegistered<T>(_ type: T.Type) -> Bool {
        DependencyContainer.live.resolve(type) != nil
    }

    /// KeyPath 기반 등록 여부 확인
    static func isRegistered<T>(_ keyPath: KeyPath<DependencyContainer, T?>) -> Bool {
        isRegistered(T.self)
    }

    /// 현재 컨테이너의 상태 정보를 반환합니다
    static func getContainerStatus() async -> DIContainerStatus {
        return DIContainerStatus(
            isBootstrapped: await DependencyContainer.isBootstrapped,
            registrationCount: getApproximateRegistrationCount(),
            memoryUsage: getApproximateMemoryUsage()
        )
    }

    /// 컨테이너의 대략적인 등록 개수를 반환합니다 (디버그 용도)
    private static func getApproximateRegistrationCount() -> Int {
        // 실제 구현에서는 DependencyContainer의 내부 상태를 확인
        return 0 // Placeholder
    }

    /// 컨테이너의 대략적인 메모리 사용량을 반환합니다 (디버그 용도)
    private static func getApproximateMemoryUsage() -> Int {
        // 실제 구현에서는 메모리 프로파일링 도구 사용
        return 0 // Placeholder
    }
}

// MARK: - Bulk Operations

public extension DI {

    /// 여러 의존성을 배치로 등록합니다
    /// - Parameter registrations: 등록할 의존성들의 배열
    static func registerMany(@DIRegistrationBuilder _ registrations: () -> [Registration]) {
        let regs = registrations()
        for registration in regs {
            registration.apply()
        }
    }
}

// MARK: - DI Registration Builder

@resultBuilder
public struct DIRegistrationBuilder {
    public static func buildBlock(_ components: Registration...) -> [Registration] {
        return components
    }
}

public struct Registration {
    private let registrationAction: () -> Void

    public init<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        self.registrationAction = {
            DI.register(type, factory: factory)
        }
    }

    public init<T>(
        _ type: T.Type,
        condition: Bool,
        factory: @escaping @Sendable () -> T,
        fallback: @escaping @Sendable () -> T
    ) {
        self.registrationAction = {
            DI.registerIf(type, condition: condition, factory: factory, fallback: fallback)
        }
    }

    fileprivate func apply() {
        registrationAction()
    }
}

// MARK: - Container Status

/// DI 컨테이너의 현재 상태 정보
public struct DIContainerStatus {
    public let isBootstrapped: Bool
    public let registrationCount: Int
    public let memoryUsage: Int
    public let timestamp: Date

    public init(isBootstrapped: Bool, registrationCount: Int, memoryUsage: Int) {
        self.isBootstrapped = isBootstrapped
        self.registrationCount = registrationCount
        self.memoryUsage = memoryUsage
        self.timestamp = Date()
    }
}

// MARK: - Diagnostic Utilities

#if DEBUG
public extension DI {
    /// 디버그 정보를 출력합니다
    static func printDebugInfo() async {
        let status = await getContainerStatus()
        print("""
        📊 [DI Debug Info]
        ==================
        Bootstrap: \(status.isBootstrapped ? "✅" : "❌")
        Registrations: \(status.registrationCount)
        Memory Usage: \(status.memoryUsage) bytes
        Timestamp: \(status.timestamp)
        """)
    }

    /// 타입별 해결 성능을 테스트합니다
    static func performanceTest<T>(_ type: T.Type, iterations: Int = 1000) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            _ = resolve(type)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        print("🔬 [DI Performance] \(type): \(duration * 1000)ms for \(iterations) iterations")
        return duration
    }
}
#endif

// MARK: - Compatibility

public extension DI {

    /// Legacy API 호환성을 위한 메서드
    /// - Warning: 사용하지 마세요. `register(_:factory:)` 사용 권장
    @available(*, deprecated, message: "Use register(_:factory:) instead")
  static func legacyRegister<T>(_ type: T.Type, _ factory: @Sendable @escaping () -> T) {
        register(type, factory: factory)
    }

    /// Legacy API 호환성을 위한 메서드
    /// - Warning: 사용하지 마세요. `resolve(_:)` 사용 권장
    @available(*, deprecated, message: "Use resolve(_:) instead")
    static func legacyResolve<T>(_ type: T.Type) -> T? {
        return resolve(type)
    }
}
