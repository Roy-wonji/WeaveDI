//
//  ModuleExtensions.swift
//  DiContainer
//
//  Created by Claude on 2025-09-14.
//

import Foundation

// MARK: - Enhanced Module System

/// 확장된 Module 시스템을 위한 고급 인터페이스
///
/// ## 개요
///
/// 기존의 단순한 `Module` 구조체를 확장하여 다음과 같은 고급 기능을 제공합니다:
/// - 모듈 간 의존성 관리
/// - 라이프사이클 훅 (등록 전후 처리)
/// - 조건부 모듈 로딩
/// - 모듈 그룹화 및 합성
/// - 검증 및 헬스 체크

public protocol AdvancedModule: Sendable {
    /// 모듈의 고유 식별자
    var identifier: String { get }

    /// 이 모듈이 의존하는 다른 모듈들의 식별자
    var dependencies: [String] { get }

    /// 모듈 등록 조건 (true일 때만 등록됨)
    var shouldRegister: @Sendable () -> Bool { get }

    /// 등록 전 실행되는 훅
    func beforeRegister() async throws

    /// 실제 등록 작업
    func register() async throws

    /// 등록 후 실행되는 훅
    func afterRegister() async throws

    /// 모듈 검증 (등록 후 정상 동작 확인)
    func validate() async throws
}

// MARK: - ConditionalModule

/// 조건부 모듈 등록을 위한 구조체
///
/// ## 사용 예시
/// ```swift
/// let analyticsModule = ConditionalModule(
///     identifier: "analytics",
///     condition: { ProcessInfo.processInfo.environment["ANALYTICS_ENABLED"] == "true" },
///     module: Module(AnalyticsService.self) { GoogleAnalytics() }
/// )
/// ```
public struct ConditionalModule: AdvancedModule {
    public let identifier: String
    public let dependencies: [String]
    public let shouldRegister: @Sendable () -> Bool

    private let baseModule: Module
    private let beforeHook: (@Sendable () async throws -> Void)?
    private let afterHook: (@Sendable () async throws -> Void)?
    private let validator: (@Sendable () async throws -> Void)?

    public init(
        identifier: String,
        dependencies: [String] = [],
        condition: @Sendable @escaping () -> Bool,
        module: Module,
        beforeRegister: (@Sendable () async throws -> Void)? = nil,
        afterRegister: (@Sendable () async throws -> Void)? = nil,
        validator: (@Sendable () async throws -> Void)? = nil
    ) {
        self.identifier = identifier
        self.dependencies = dependencies
        self.shouldRegister = condition
        self.baseModule = module
        self.beforeHook = beforeRegister
        self.afterHook = afterRegister
        self.validator = validator
    }

    public func beforeRegister() async throws {
        try await beforeHook?()
    }

    public func register() async throws {
        await baseModule.register()
    }

    public func afterRegister() async throws {
        try await afterHook?()
    }

    public func validate() async throws {
        try await validator?()
    }
}

// MARK: - ModuleGroup

/// 여러 모듈을 그룹으로 관리하는 구조체
///
/// ## 사용 예시
/// ```swift
/// let networkModules = ModuleGroup(
///     identifier: "network-stack",
///     modules: [
///         httpClientModule,
///         authServiceModule,
///         apiServiceModule
///     ]
/// )
/// ```
public struct ModuleGroup: AdvancedModule {
    public let identifier: String
    public let dependencies: [String]
    public let shouldRegister: @Sendable () -> Bool

    private let modules: [AdvancedModule]
    private let parallelRegistration: Bool

    public init(
        identifier: String,
        dependencies: [String] = [],
        condition: @Sendable @escaping () -> Bool = { true },
        modules: [AdvancedModule],
        parallelRegistration: Bool = false
    ) {
        self.identifier = identifier
        self.dependencies = dependencies
        self.shouldRegister = condition
        self.modules = modules
        self.parallelRegistration = parallelRegistration
    }

    public func beforeRegister() async throws {
        for module in modules {
            try await module.beforeRegister()
        }
    }

    public func register() async throws {
        if parallelRegistration {
            // 병렬 등록 (의존성 무시하고 동시 실행)
            try await withThrowingTaskGroup(of: Void.self) { group in
                for module in modules {
                    if module.shouldRegister() {
                        group.addTask {
                            try await module.register()
                        }
                    }
                }
                try await group.waitForAll()
            }
        } else {
            // 순차 등록 (의존성 순서 고려)
            let sortedModules = try topologicalSort(modules: modules)
            for module in sortedModules {
                if module.shouldRegister() {
                    try await module.register()
                }
            }
        }
    }

    public func afterRegister() async throws {
        for module in modules {
            try await module.afterRegister()
        }
    }

    public func validate() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for module in modules {
                group.addTask {
                    try await module.validate()
                }
            }
            try await group.waitForAll()
        }
    }

    /// 모듈들을 의존성 순서에 따라 위상정렬
    private func topologicalSort(modules: [AdvancedModule]) throws -> [AdvancedModule] {
        var visited = Set<String>()
        var visiting = Set<String>()
        var result: [AdvancedModule] = []
        let moduleDict = Dictionary(uniqueKeysWithValues: modules.map { ($0.identifier, $0) })

        func visit(_ moduleId: String) throws {
            if visiting.contains(moduleId) {
                throw ModuleSystemError.circularDependency(moduleId)
            }
            if visited.contains(moduleId) {
                return
            }

            guard let module = moduleDict[moduleId] else {
                throw ModuleSystemError.moduleNotFound(moduleId)
            }

            visiting.insert(moduleId)
            for dependency in module.dependencies {
                try visit(dependency)
            }
            visiting.remove(moduleId)
            visited.insert(moduleId)
            result.append(module)
        }

        for module in modules {
            try visit(module.identifier)
        }

        return result
    }
}

// MARK: - ModuleBuilder

/// DSL 스타일로 모듈을 구성하기 위한 Result Builder
@resultBuilder
public struct ModuleBuilder {
    public static func buildBlock(_ components: AdvancedModule...) -> [AdvancedModule] {
        return components
    }

    public static func buildArray(_ components: [[AdvancedModule]]) -> [AdvancedModule] {
        return components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [AdvancedModule]?) -> [AdvancedModule] {
        return component ?? []
    }

    public static func buildEither(first component: [AdvancedModule]) -> [AdvancedModule] {
        return component
    }

    public static func buildEither(second component: [AdvancedModule]) -> [AdvancedModule] {
        return component
    }
}

// MARK: - ModuleRegistry

/// 모듈 등록 및 관리를 위한 레지스트리
@MainActor
public final class ModuleRegistry: ObservableObject {
    @Published public private(set) var registeredModules: [String: AdvancedModule] = [:]
    @Published public private(set) var registrationStatus: [String: ModuleRegistrationStatus] = [:]

    public static let shared = ModuleRegistry()

    private init() {}

    /// 모듈 등록 (DSL 스타일 지원)
    public func registerModules(@ModuleBuilder builder: () -> [AdvancedModule]) async throws {
        let modules = builder()
        try await registerModules(modules)
    }

    /// 모듈 배열 등록
    public func registerModules(_ modules: [AdvancedModule]) async throws {
        // 1. 모듈 검증 및 의존성 체크
        try validateModules(modules)

        // 2. 위상 정렬
        let sortedModules = try topologicalSort(modules: modules)

        // 3. 단계별 등록 실행
        for module in sortedModules {
            if module.shouldRegister() {
                await registerSingleModule(module)
            }
        }

        // 4. 전체 검증
        try await validateAllModules()
    }

    private func validateModules(_ modules: [AdvancedModule]) throws {
        let identifiers = Set(modules.map(\.identifier))

        for module in modules {
            // 중복 식별자 체크
            if registeredModules.keys.contains(module.identifier) {
                throw ModuleSystemError.duplicateModule(module.identifier)
            }

            // 의존성 존재 체크
            for dependency in module.dependencies {
                if !identifiers.contains(dependency) && !registeredModules.keys.contains(dependency) {
                    throw ModuleSystemError.missingDependency(module.identifier, dependency)
                }
            }
        }
    }

    private func topologicalSort(modules: [AdvancedModule]) throws -> [AdvancedModule] {
        var visited = Set<String>()
        var visiting = Set<String>()
        var result: [AdvancedModule] = []
        let moduleDict = Dictionary(uniqueKeysWithValues: modules.map { ($0.identifier, $0) })

        func visit(_ moduleId: String) throws {
            if visiting.contains(moduleId) {
                throw ModuleSystemError.circularDependency(moduleId)
            }
            if visited.contains(moduleId) {
                return
            }

            guard let module = moduleDict[moduleId] else {
                throw ModuleSystemError.moduleNotFound(moduleId)
            }

            visiting.insert(moduleId)
            for dependency in module.dependencies {
                try visit(dependency)
            }
            visiting.remove(moduleId)
            visited.insert(moduleId)
            result.append(module)
        }

        for module in modules {
            try visit(module.identifier)
        }

        return result
    }

    private func registerSingleModule(_ module: AdvancedModule) async {
        registrationStatus[module.identifier] = .registering

        do {
            try await module.beforeRegister()
            try await module.register()
            try await module.afterRegister()
            try await module.validate()

            registeredModules[module.identifier] = module
            registrationStatus[module.identifier] = .registered

            #if DEBUG
            print("✅ [ModuleRegistry] Successfully registered module: \(module.identifier)")
            #endif
        } catch {
            registrationStatus[module.identifier] = .failed(error)

            #if DEBUG
            print("❌ [ModuleRegistry] Failed to register module \(module.identifier): \(error)")
            #endif
        }
    }

    private func validateAllModules() async throws {
        for (identifier, module) in registeredModules {
            do {
                try await module.validate()
                #if DEBUG
                print("✅ [ModuleRegistry] Validation passed for module: \(identifier)")
                #endif
            } catch {
                #if DEBUG
                print("❌ [ModuleRegistry] Validation failed for module \(identifier): \(error)")
                #endif
                throw ModuleSystemError.validationFailed(identifier, error)
            }
        }
    }

    /// 특정 모듈의 등록 상태 확인
    public func status(for moduleId: String) -> ModuleRegistrationStatus? {
        return registrationStatus[moduleId]
    }

    /// 모든 모듈 제거 (테스트 용도)
    public func removeAllModules() {
        registeredModules.removeAll()
        registrationStatus.removeAll()
    }
}

// MARK: - ModuleRegistrationStatus

public enum ModuleRegistrationStatus: Sendable {
    case registering
    case registered
    case failed(Error)

    public var isRegistered: Bool {
        if case .registered = self {
            return true
        }
        return false
    }

    public var error: Error? {
        if case let .failed(error) = self {
            return error
        }
        return nil
    }
}

// MARK: - ModuleSystemError

public enum ModuleSystemError: Error, LocalizedError {
    case duplicateModule(String)
    case moduleNotFound(String)
    case missingDependency(String, String)
    case circularDependency(String)
    case validationFailed(String, Error)

    public var errorDescription: String? {
        switch self {
        case .duplicateModule(let id):
            return "중복된 모듈 식별자: \(id)"
        case .moduleNotFound(let id):
            return "모듈을 찾을 수 없습니다: \(id)"
        case .missingDependency(let module, let dependency):
            return "모듈 \(module)의 의존성 \(dependency)를 찾을 수 없습니다"
        case .circularDependency(let id):
            return "순환 의존성 발견: \(id)"
        case .validationFailed(let id, let error):
            return "모듈 \(id) 검증 실패: \(error.localizedDescription)"
        }
    }
}

// MARK: - Convenience Extensions

/// 기존 Module을 AdvancedModule로 래핑하는 확장
public extension Module {
    func asAdvanced(
        identifier: String,
        dependencies: [String] = [],
        condition: @Sendable @escaping () -> Bool = { true }
    ) -> ConditionalModule {
        return ConditionalModule(
            identifier: identifier,
            dependencies: dependencies,
            condition: condition,
            module: self
        )
    }
}

/// 편의 생성자들
public extension ConditionalModule {
    /// 환경 변수 기반 조건부 모듈
    static func fromEnvironment(
        identifier: String,
        dependencies: [String] = [],
        envKey: String,
        expectedValue: String,
        module: Module
    ) -> ConditionalModule {
        return ConditionalModule(
            identifier: identifier,
            dependencies: dependencies,
            condition: {
                ProcessInfo.processInfo.environment[envKey] == expectedValue
            },
            module: module
        )
    }

    /// UserDefaults 기반 조건부 모듈
    static func fromUserDefault(
        identifier: String,
        dependencies: [String] = [],
        key: String,
        module: Module
    ) -> ConditionalModule {
        return ConditionalModule(
            identifier: identifier,
            dependencies: dependencies,
            condition: {
                UserDefaults.standard.bool(forKey: key)
            },
            module: module
        )
    }

    /// 빌드 구성 기반 조건부 모듈
    static func debugOnly(
        identifier: String,
        dependencies: [String] = [],
        module: Module
    ) -> ConditionalModule {
        return ConditionalModule(
            identifier: identifier,
            dependencies: dependencies,
            condition: {
                #if DEBUG
                return true
                #else
                return false
                #endif
            },
            module: module
        )
    }
}