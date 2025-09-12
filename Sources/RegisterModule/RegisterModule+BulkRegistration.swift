//
//  RegisterModule+BulkRegistration.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - 사용자 패턴 한번에 등록 시스템

public extension RegisterModule {
    
    /// 인터페이스 패턴을 한번에 등록하는 시스템
    /// 
    /// ## 사용법:
    /// ```swift
    /// let modules = registerModule.registerInterfacePattern(
    ///     AuthInterface.self,
    ///     repositoryFactory: { AuthRepositoryImpl() },
    ///     useCaseFactory: { repo in AuthUseCaseImpl(repository: repo) },
    ///     repositoryFallback: { DefaultAuthRepositoryImpl() }
    /// )
    /// ```
    func registerInterfacePattern<Interface>(
        _ interfaceType: Interface.Type,
        repositoryFactory: @Sendable @escaping () -> Interface,
        useCaseFactory: @Sendable @escaping (Interface) -> Interface,
        repositoryFallback: @Sendable @escaping () -> Interface
    ) -> [() -> Module] {
        
        let repositoryModule = makeDependency(interfaceType, factory: repositoryFactory)

        let useCaseModule = makeUseCaseWithRepository(
            interfaceType,
            repositoryProtocol: interfaceType,
            repositoryFallback: repositoryFallback(),
            factory: useCaseFactory
        )
        
        return [repositoryModule, useCaseModule]
    }
    
    /// 사용자의 기존 패턴과 완전히 동일한 한번에 등록
    /// 
    /// ## 사용법 (사용자의 기존 코드와 1:1 대응):
    /// ```swift
    /// // 기존 코드를 이렇게 변환:
    /// let modules = registerModule.interface(
    ///     AuthInterface.self,
    ///     repository: { AuthRepositoryImpl() },
    ///     useCase: { repo in AuthUseCaseImpl(repository: repo) },
    ///     fallback: { DefaultAuthRepositoryImpl() }
    /// )
    /// 
    /// // 등록
    /// for moduleFactory in modules {
    ///     await container.register(moduleFactory())
    /// }
    /// ```
     func interface<Interface>(
        _ interfaceType: Interface.Type,
        repository repositoryFactory: @Sendable @escaping () -> Interface,
        useCase useCaseFactory: @Sendable @escaping (Interface) -> Interface,
        fallback fallbackFactory: @Sendable @escaping () -> Interface
    ) -> [() -> Module] {
        
        return [
            // Repository 모듈 (기존 authRepositoryImplModule과 동일)
            makeDependency(interfaceType, factory: repositoryFactory),
            
            // UseCase 모듈 (기존 authUseCaseImplModule과 동일)
            makeUseCaseWithRepository(
                interfaceType,
                repositoryProtocol: interfaceType,
                repositoryFallback: fallbackFactory(),
                factory: useCaseFactory
            )
        ]
    }
    
    /// 여러 인터페이스를 한번에 등록하는 시스템
    /// 
    /// ## 사용법:
    /// ```swift
    /// let allModules = registerModule.bulkInterfaces {
    ///     AuthInterface.self => (
    ///         repository: { AuthRepositoryImpl() },
    ///         useCase: { repo in AuthUseCaseImpl(repository: repo) },
    ///         fallback: { DefaultAuthRepositoryImpl() }
    ///     )
    ///     UserInterface.self => (
    ///         repository: { UserRepositoryImpl() },
    ///         useCase: { repo in UserUseCaseImpl(repository: repo) },
    ///         fallback: { DefaultUserRepositoryImpl() }
    ///     )
    /// }
    /// ```
    func bulkInterfaces(@BulkRegistrationBuilder _ builder: () -> [BulkRegistrationEntry]) -> [() -> Module] {
        let entries = builder()
        var allModules: [() -> Module] = []
        
        for entry in entries {
            let modules = entry.createModules(using: self)
            allModules.append(contentsOf: modules)
        }
        
        return allModules
    }
}

// MARK: - Bulk Registration DSL

/// 벌크 등록을 위한 빌더
@resultBuilder
public struct BulkRegistrationBuilder {
    public static func buildBlock(_ components: BulkRegistrationEntry...) -> [BulkRegistrationEntry] {
        Array(components)
    }
}

/// 벌크 등록 엔트리
public struct BulkRegistrationEntry {
    private let createModulesFunc: (RegisterModule) -> [() -> Module]
    
    public init<Interface>(
        interfaceType: Interface.Type,
        repository: @Sendable @escaping () -> Interface,
        useCase: @Sendable @escaping (Interface) -> Interface,
        fallback: @Sendable @escaping () -> Interface
    ) {
        self.createModulesFunc = { registerModule in
            registerModule.interface(
                interfaceType,
                repository: repository,
                useCase: useCase,
                fallback: fallback
            )
        }
    }
    
    func createModules(using registerModule: RegisterModule) -> [() -> Module] {
        return createModulesFunc(registerModule)
    }
}

// MARK: - DSL Operators

infix operator => : AssignmentPrecedence

/// 벌크 등록을 위한 연산자
public func =><Interface>(
    lhs: Interface.Type,
    rhs: (
        repository: @Sendable () -> Interface, 
        useCase: @Sendable (Interface) -> Interface, 
        fallback: @Sendable () -> Interface
    )
) -> BulkRegistrationEntry {
    BulkRegistrationEntry(
        interfaceType: lhs,
        repository: rhs.repository,
        useCase: rhs.useCase,
        fallback: rhs.fallback
    )
}

// MARK: - 전역 편의 함수

/// 사용자를 위한 전역 인터페이스 등록 함수
public func registerInterface<Interface>(
    _ interfaceType: Interface.Type,
    repository: @Sendable @escaping () -> Interface,
    useCase: @Sendable @escaping (Interface) -> Interface,
    fallback: @Sendable @escaping () -> Interface
) -> [() -> Module] {
    let registerModule = RegisterModule()
    return registerModule.interface(
        interfaceType,
        repository: repository,
        useCase: useCase,
        fallback: fallback
    )
}
