//
//  RegisterModuleCore.swift
//  DiContainer
//
//  Created by Wonji Suh on 3/24/25.
//

import Foundation
import LogMacro

/// RegisterModule의 핵심 기능만 포함한 깔끔한 버전
public struct RegisterModule: Sendable {
    
    // MARK: - 초기화
    
    /// 기본 생성자
    public init() {}
    
    // MARK: - 기본 모듈 생성
    
    /// 타입과 팩토리 클로저로부터 Module 인스턴스를 생성하는 기본 메서드입니다.
    public func makeModule<T>(
        _ type: T.Type,
        factory: @Sendable @escaping () -> T
    ) -> Module {
        Module(type, factory: factory)
    }
    
    /// 특정 프로토콜 타입에 대해 Module을 생성하는 클로저를 반환합니다.
    public func makeDependency<T>(
        _ protocolType: T.Type,
        factory: @Sendable @escaping () -> T
    ) -> @Sendable () -> Module {
        return {
            Module(protocolType, factory: factory)
        }
    }
    
    
    // MARK: - UseCase with Repository 패턴
    
    /// UseCase 모듈 생성 시, DI 컨테이너에서 Repository 인스턴스를 자동으로 주입합니다.
    public func makeUseCaseWithRepository<UseCase, Repo>(
        _ useCaseProtocol: UseCase.Type,
        repositoryProtocol: Repo.Type,
        repositoryFallback: @Sendable @autoclosure @escaping () -> Repo,
        factory: @Sendable @escaping (Repo) -> UseCase
    ) -> @Sendable () -> Module {
        
        return {
            // Repository 조회
            let repository: Repo = self.resolveOrDefault(
                for: repositoryProtocol,
                fallback: repositoryFallback()
            )
            
            return Module(useCaseProtocol, factory: {
                factory(repository)
            })
        }
    }
    
    // MARK: - 의존성 조회 헬퍼
    
    /// 의존성을 조회하고, 없을 경우 기본값을 반환합니다.
    public func resolveOrDefault<T>(
        for type: T.Type,
        fallback: @Sendable @autoclosure @escaping () -> T
    ) -> T {
        if let resolved: T = DependencyContainer.live.resolve(type) {
            return resolved
        }
        return fallback()
    }
    
    /// 기본 인스턴스를 제공합니다.
    public func defaultInstance<T>(
        for type: T.Type,
        fallback: @Sendable @autoclosure @escaping () -> T
    ) -> T {
        return resolveOrDefault(for: type, fallback: fallback())
    }
}

// MARK: - BookList 예시 적용

public extension RegisterModule {
    
    /// 🔥 새로운 방식: BookList 인터페이스를 한번에 등록
    var bookListModules: [() -> Module] {
        return interface(
            BookListInterface.self,
            repository: { BookListRepositoryImpl() },
            useCase: { repo in BookListUseCaseImpl(repository: repo) },
            fallback: { DefaultBookListRepositoryImpl() }
        )
    }

    /// 기존 방식 (하위 호환성 유지)
    var bookListUseCaseImplModule: () -> Module {
        makeUseCaseWithRepository(
            BookListInterface.self,
            repositoryProtocol: BookListInterface.self,
            repositoryFallback: DefaultBookListRepositoryImpl(),
            factory: { repo in
                BookListUseCaseImpl(repository: repo)
            }
        )
    }

    var bookListRepositoryImplModule: () -> Module {
        makeDependency(BookListInterface.self) {
            BookListRepositoryImpl()
        }
    }
}