//
//  RegistrationCore.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/19/25.
//

import Foundation
import LogMacro

// MARK: - Module

/// `Module`은 DI(의존성 주입)를 위한 **단일 모듈**을 나타내는 구조체입니다.
///
/// 이 타입을 사용하면, 특정 타입의 인스턴스를 `DependencyContainer`에
/// **비동기적으로 등록**하는 작업을 하나의 객체로 캡슐화할 수 있습니다.
public actor Module {
    private let registrationClosure: () async -> Void

    public init<T>(
        _ type: T.Type,
        factory: @Sendable @escaping () -> T
    ) {
        self.registrationClosure = {
            DependencyContainer.live.register(type, build: factory)
        }
    }

    public func register() async {
        await registrationClosure()
    }
}

// MARK: - RegisterModule

/// RegisterModule의 핵심 기능만 포함한 깔끔한 버전
public struct RegisterModule: Sendable {

    public init() {}

    // MARK: - 기본 모듈 생성

    public func makeModule<T>(
        _ type: T.Type,
        factory: @Sendable @escaping () -> T
    ) -> Module {
        Module(type, factory: factory)
    }

    public func makeDependency<T>(
        _ protocolType: T.Type,
        factory: @Sendable @escaping () -> T
    ) -> @Sendable () -> Module {
        return {
            Module(protocolType, factory: factory)
        }
    }

    // MARK: - UseCase with Repository 패턴

    public func makeUseCaseWithRepository<UseCase, Repo>(
        _ useCaseProtocol: UseCase.Type,
        repositoryProtocol: Repo.Type,
        repositoryFallback: @Sendable @autoclosure @escaping () -> Repo,
        factory: @Sendable @escaping (Repo) -> UseCase
    ) -> @Sendable () -> Module {
        return { [repositoryProtocol] in
            Module(useCaseProtocol, factory: {
                if let repo: Repo = DependencyContainer.live.resolve(repositoryProtocol) {
                    return factory(repo)
                } else {
                    let fallbackRepo = repositoryFallback()
                    return factory(fallbackRepo)
                }
            })
        }
    }

    // MARK: - 의존성 조회 헬퍼

    public func resolveOrDefault<T>(
        for type: T.Type,
        fallback: @Sendable @autoclosure @escaping () -> T
    ) -> T {
        if let resolved: T = DependencyContainer.live.resolve(type) {
            return resolved
        }
        return fallback()
    }

    public func interface<Interface>(
        _ interfaceType: Interface.Type,
        repository repositoryFactory: @Sendable @escaping () -> Interface,
        useCase useCaseFactory: @Sendable @escaping (Interface) -> Interface,
        fallback fallbackFactory: @Sendable @escaping () -> Interface
    ) -> [() -> Module] {
        return [
            makeDependency(interfaceType, factory: repositoryFactory),
            makeUseCaseWithRepository(
                interfaceType,
                repositoryProtocol: interfaceType,
                repositoryFallback: fallbackFactory(),
                factory: useCaseFactory
            )
        ]
    }

    public func defaultInstance<T>(
        for type: T.Type,
        fallback: @Sendable @autoclosure @escaping () -> T
    ) -> T {
        return resolveOrDefault(for: type, fallback: fallback())
    }
}

// MARK: - Sendable Helpers

/// A lightweight helper to intentionally box non-Sendable values
/// for use inside @Sendable closures. Use with caution and only if
/// you can guarantee thread-safety of the underlying value.
public struct UncheckedSendableBox<T>: @unchecked Sendable {
    public let value: T
    public init(_ value: T) { self.value = value }
}

/// Convenience function to create an UncheckedSendableBox
@inlinable
public func unsafeSendable<T>(_ value: T) -> UncheckedSendableBox<T> {
    UncheckedSendableBox(value)
}