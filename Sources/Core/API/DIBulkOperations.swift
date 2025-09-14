//
//  DIBulkOperations.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - DI Bulk Operations API

public extension DI {

    // MARK: - Bulk Registration

    /// 여러 의존성을 한번에 등록합니다
    /// - Parameter registrations: 등록할 의존성 목록
    static func registerMany(@DIRegistrationBuilder _ registrations: () -> [DIRegistration]) {
        let items = registrations()
        for registration in items {
            registration.register()
        }
    }

    /// DSL 스타일로 여러 의존성을 등록합니다
    ///
    /// ## 사용 예시:
    /// ```swift
    /// DI.registerMany {
    ///     DIRegistration(UserService.self) { DefaultUserService() }
    ///     DIRegistration(NetworkService.self, singleton: URLSession.shared)
    ///     DIRegistration(DatabaseService.self) { CoreDataService() }
    /// }
    /// ```
    static func setup(@DIRegistrationBuilder _ registrations: () -> [DIRegistration]) {
        registerMany(registrations)
    }

    /// 비동기적으로 여러 의존성을 등록합니다
    static func registerManyAsync(@DIRegistrationBuilder _ registrations: () -> [DIRegistration]) async {
        let items = registrations()

        // 병렬로 등록 (의존성이 없는 경우에만 안전)
        await withTaskGroup(of: Void.self) { group in
            for registration in items {
                group.addTask { @Sendable in
                    registration.register()
                }
            }
        }
    }

    /// 조건부 대량 등록
    static func registerManyIf(
        condition: Bool,
        @DIRegistrationBuilder _ registrations: () -> [DIRegistration]
    ) {
        guard condition else { return }
        registerMany(registrations)
    }

    /// 환경별 대량 등록
    static func registerForEnvironment(
        _ environment: DIEnvironment,
        @DIRegistrationBuilder _ registrations: () -> [DIRegistration]
    ) {
        guard environment.isCurrentEnvironment else { return }
        registerMany(registrations)
    }
}

// MARK: - Result Builder for Bulk Registration

@resultBuilder
public struct DIRegistrationBuilder {
    public static func buildBlock(_ components: DIRegistration...) -> [DIRegistration] {
        return components
    }

    public static func buildArray(_ components: [[DIRegistration]]) -> [DIRegistration] {
        return components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [DIRegistration]?) -> [DIRegistration] {
        return component ?? []
    }

    public static func buildEither(first component: [DIRegistration]) -> [DIRegistration] {
        return component
    }

    public static func buildEither(second component: [DIRegistration]) -> [DIRegistration] {
        return component
    }

    public static func buildExpression(_ expression: DIRegistration) -> [DIRegistration] {
        return [expression]
    }

    public static func buildExpression(_ expression: [DIRegistration]) -> [DIRegistration] {
        return expression
    }
}

// MARK: - Registration Item

public struct DIRegistration: @unchecked Sendable {
    private let registerAction: @Sendable () -> Void

    public init<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        self.registerAction = { @Sendable in
            DI.register(type, factory: factory)
        }
    }

    public init<T: Sendable>(_ type: T.Type, singleton instance: T) {
        self.registerAction = { @Sendable in
            // 싱글톤 등록을 위해 인스턴스를 캡처하는 팩토리 생성
            let capturedInstance = instance
            DI.register(type) { capturedInstance }
        }
    }

    public init<T>(
        _ keyPath: KeyPath<DependencyContainer, T?>,
        factory: @escaping @Sendable () -> T
    ) {
        // KeyPath는 @Sendable이 아니므로, 타입만 캡처하여 등록
        let type = T.self
        self.registerAction = { @Sendable in
            DI.register(type, factory: factory)
        }
    }

    public init<T>(
        _ type: T.Type,
        condition: Bool,
        factory: @escaping @Sendable () -> T,
        fallback: @escaping @Sendable () -> T
    ) {
        self.registerAction = { @Sendable in
            DI.registerIf(type, condition: condition, factory: factory, fallback: fallback)
        }
    }

    internal func register() {
        registerAction()
    }
}

// MARK: - Environment Support

public enum DIEnvironment: String, CaseIterable {
    case development = "development"
    case staging = "staging"
    case production = "production"
    case testing = "testing"

    /// 현재 환경인지 확인
    public var isCurrentEnvironment: Bool {
        return DIEnvironment.currentEnvironment == self
    }

    /// 현재 실행 환경을 반환
    public static var currentEnvironment: DIEnvironment {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .testing
        }
        return .development
        #else
        if let envString = ProcessInfo.processInfo.environment["DI_ENVIRONMENT"],
           let env = DIEnvironment(rawValue: envString) {
            return env
        }
        return .production
        #endif
    }

    /// 환경별 설명
    public var description: String {
        switch self {
        case .development:
            return "개발 환경"
        case .staging:
            return "스테이징 환경"
        case .production:
            return "프로덕션 환경"
        case .testing:
            return "테스트 환경"
        }
    }
}

// MARK: - Convenience Extensions

public extension DIRegistration {
    /// 개발 환경에서만 등록
    static func developmentOnly<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) -> DIRegistration {
        return DIRegistration(
            type,
            condition: DIEnvironment.currentEnvironment == .development,
            factory: factory,
            fallback: { fatalError("Development-only dependency accessed in \(DIEnvironment.currentEnvironment)") }
        )
    }

    /// 프로덕션 환경에서만 등록
    static func productionOnly<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) -> DIRegistration {
        return DIRegistration(
            type,
            condition: DIEnvironment.currentEnvironment == .production,
            factory: factory,
            fallback: { fatalError("Production-only dependency accessed in \(DIEnvironment.currentEnvironment)") }
        )
    }

    /// 테스트 환경에서만 등록
    static func testingOnly<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) -> DIRegistration {
        return DIRegistration(
            type,
            condition: DIEnvironment.currentEnvironment == .testing,
            factory: factory,
            fallback: { fatalError("Testing-only dependency accessed in \(DIEnvironment.currentEnvironment)") }
        )
    }
}
