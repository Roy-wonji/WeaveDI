//
//  RepositoryModuleFactoryProtocol.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

/// `RepositoryModuleFactoryProtocol`은 Repository 모듈을 생성하는 기본 인터페이스를 정의합니다.
/// 이 프로토콜을 채택하는 타입은 의존성 등록 헬퍼 객체(`registerModule`)와,
/// Repository 모듈 생성 클로저 배열(`repositoryDefinitions`), 그리고 이 클로저들을 실행하여 모듈들을 생성하는 기능을 제공해야 합니다.
#if swift(>=5.9)
@available(iOS 17.0, *)
public protocol RepositoryModuleFactoryProtocol {
    // MARK: - 프로퍼티

    /// 의존성 등록을 위한 헬퍼 객체.
    /// 이 객체는 Repository 모듈 생성에 필요한 의존성들을 등록하는 역할을 수행합니다.
    var registerModule: RegisterModule { get }

    /// Repository 모듈을 생성하는 클로저들의 배열.
    /// 각 클로저는 호출 시 `Module` 인스턴스를 생성하여 반환합니다.
    var repositoryDefinitions: [() -> Module] { get }

    // MARK: - 메서드

    /// `repositoryDefinitions` 배열의 모든 클로저를 실행하여, 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    func makeAllModules() -> [Module]
}

#else
public protocol RepositoryModuleFactoryProtocol {
    // MARK: - 프로퍼티

    var registerModule: RegisterModule { get }
    var repositoryDefinitions: [() -> Module] { get }

    // MARK: - 메서드

    func makeAllModules() -> [Module]
}
#endif

/// `RepositoryModuleFactoryProtocol`의 기본 구현을 제공하는 `extension`입니다.
/// `makeAllModules()` 메서드는 `repositoryDefinitions` 배열에 있는 모든 클로저를 순회하며 실행합니다.
#if swift(>=5.9)
@available(iOS 17.0, *)
public extension RepositoryModuleFactoryProtocol {
    /// `repositoryDefinitions` 배열의 모든 클로저를 호출하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    func makeAllModules() -> [Module] {
        repositoryDefinitions.map { $0() }
    }
}
#else
public extension RepositoryModuleFactoryProtocol {
    /// `repositoryDefinitions` 배열의 모든 클로저를 호출하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    func makeAllModules() -> [Module] {
        repositoryDefinitions.map { $0() }
    }
}
#endif
