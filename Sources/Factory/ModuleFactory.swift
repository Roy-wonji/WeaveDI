//
//  ModuleFactory.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Generic Module Factory Protocol

/// 모든 모듈 팩토리의 공통 인터페이스입니다.
/// Repository, UseCase, Scope 모듈을 통합하여 중복을 제거합니다.
public protocol ModuleFactory {
    /// 모듈 생성 시 필요한 의존성 등록 헬퍼
    var registerModule: RegisterModule { get }

    /// 모듈을 생성하는 클로저들의 배열 (Sendable)
    var definitions: [@Sendable () -> Module] { get set }

    /// 모든 모듈 인스턴스를 생성합니다
    func makeAllModules() -> [Module]
}

// MARK: - Default Implementation

public extension ModuleFactory {
    func makeAllModules() -> [Module] {
        return definitions.map { $0() }
    }
}

// MARK: - Specialized Factory Types

/// Repository 계층 모듈 팩토리
public struct RepositoryModuleFactory: ModuleFactory, Sendable {
    public let registerModule = RegisterModule()
    public var definitions: [@Sendable () -> Module] = []

    public init() {}

    /// Repository 의존성을 쉽게 추가하는 헬퍼
    public mutating func addRepository<T>(
        _ type: T.Type,
        factory: @Sendable @escaping () -> T
    ) where T: Sendable {
        let helper = registerModule
        let closure: @Sendable () -> Module = {
            helper.makeModule(type, factory: factory)
        }
        definitions.append(closure)
    }
}

/// UseCase 계층 모듈 팩토리
public struct UseCaseModuleFactory: ModuleFactory, Sendable {
    public let registerModule = RegisterModule()
    public var definitions: [@Sendable () -> Module] = []

    public init() {}

    /// UseCase와 Repository 의존성을 함께 등록하는 헬퍼
    public mutating func addUseCase<UseCase, Repo>(
        _ useCaseType: UseCase.Type,
        repositoryType: Repo.Type,
        repositoryFallback: @Sendable @escaping () -> Repo,
        factory: @Sendable @escaping (Repo) -> UseCase
    ) where UseCase: Sendable {
        let helper = registerModule
        let closure: @Sendable () -> Module = {
            helper.makeUseCaseWithRepository(
                useCaseType,
                repositoryProtocol: repositoryType,
                repositoryFallback: repositoryFallback(),
                factory: factory
            )()
        }
        definitions.append(closure)
    }
}

/// Scope 계층 모듈 팩토리
public struct ScopeModuleFactory: ModuleFactory, Sendable {
    public let registerModule = RegisterModule()
    public var definitions: [@Sendable () -> Module] = []

    public init() {}

    /// Scoped 의존성을 추가하는 헬퍼
    public mutating func addScoped<T>(
        _ type: T.Type,
        factory: @Sendable @escaping () -> T
    ) where T: Sendable {
        let helper = registerModule
        let closure: @Sendable () -> Module = {
            helper.makeModule(type, factory: factory)
        }
        definitions.append(closure)
    }
}

// MARK: - Factory Manager

/// 여러 팩토리를 한 번에 관리하는 매니저
public struct ModuleFactoryManager: Sendable {
    public var repositoryFactory = RepositoryModuleFactory()
    public var useCaseFactory = UseCaseModuleFactory()
    public var scopeFactory = ScopeModuleFactory()

    public init() {}

    /// 모든 팩토리의 모듈을 한 번에 생성
    public func makeAllModules() -> [Module] {
        var allModules: [Module] = []
        allModules.append(contentsOf: repositoryFactory.makeAllModules())
        allModules.append(contentsOf: useCaseFactory.makeAllModules())
        allModules.append(contentsOf: scopeFactory.makeAllModules())
        return allModules
    }

    /// 모든 모듈을 DI 컨테이너에 등록
    public func registerAll(to container: WeaveDI.Container) async {
        // Repository 모듈들 등록
        let repositoryModules = self.repositoryFactory.makeAllModules()
        for module in repositoryModules {
            await container.register(module)
        }

        // UseCase 모듈들 등록
        let useCaseModules = self.useCaseFactory.makeAllModules()
        for module in useCaseModules {
            await container.register(module)
        }

        // Scope 모듈들 등록
        let scopeModules = self.scopeFactory.makeAllModules()
        for module in scopeModules {
            await container.register(module)
        }
    }

    /// 기존 방식 (컨테이너 없이 직접 등록)
    public func registerAll() async {
        let modules = makeAllModules()
        for module in modules {
            await module.register()
        }
    }
}

// MARK: - Convenience Extensions

public extension ModuleFactoryManager {

    /// DSL 스타일로 의존성 정의
    mutating func setup(@ModuleDefinitionBuilder _ builder: (inout ModuleFactoryManager) -> Void) {
        builder(&self)
    }
}

/// 모듈 정의를 위한 Result Builder
@resultBuilder
public struct ModuleDefinitionBuilder {
    public static func buildBlock(_ components: (inout ModuleFactoryManager) -> Void...) -> (inout ModuleFactoryManager) -> Void {
        return { manager in
            for component in components {
                component(&manager)
            }
        }
    }
}

// MARK: - Legacy Compatibility

// 기존 코드와의 호환성을 위한 typealiases
@available(*, deprecated, message: "Use RepositoryModuleFactory instead")
public typealias RepositoryModuleFactoryProtocol = ModuleFactory

@available(*, deprecated, message: "Use UseCaseModuleFactory instead")
public typealias UseCaseModuleFactoryProtocol = ModuleFactory

@available(*, deprecated, message: "Use ScopeModuleFactory instead")
public typealias ScopeModuleFactoryProtocol = ModuleFactory
