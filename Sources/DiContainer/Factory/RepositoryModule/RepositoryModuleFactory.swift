//
//  RepositoryModuleFactory.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//


import Foundation

/// `RepositoryModuleFactoryProtocol`을 채택하는 `RepositoryModuleFactory`는
/// Repository 모듈을 생성 및 등록하는 역할을 수행하는 타입입니다.
/// 이 구조체는 의존성 등록 헬퍼(`registerModule`)와
/// 모듈 생성 클로저 배열(`repositoryDefinitions`)을 보유합니다.
#if swift(>=5.9)
@available(iOS 17.0, *)
public struct RepositoryModuleFactory: RepositoryModuleFactoryProtocol {
    // MARK: - 저장 프로퍼티

    /// 의존성 등록에 사용되는 헬퍼 객체입니다.
    /// 이 객체는 Repository 모듈 생성 시 필요한 의존성을 등록하는 역할을 합니다.
    public let registerModule = RegisterModule()

    /// Repository 모듈을 생성하는 클로저들의 배열입니다.
    /// 각 클로저는 호출 시 Repository 모듈(즉, `Module` 인스턴스)을 반환합니다.
    public var repositoryDefinitions: [() -> Module]

    // MARK: - 초기화

    /// 생성자
    ///
    /// - Parameter repositoryDefinitions: 모듈 생성 클로저 배열을 전달할 수 있습니다.
    ///   만약 `nil`이 전달되면, 기본 의존성은 빈 배열로 초기화됩니다.
    ///   (앱에서 기본 등록 로직을 `extension` 등을 통해 재정의할 수 있습니다.)
    public init(repositoryDefinitions: [() -> Module]? = nil) {
        self.repositoryDefinitions = repositoryDefinitions ?? []
    }

    // MARK: - 메서드

    /// `repositoryDefinitions` 배열의 모든 클로저를 실행하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    public func makeAllModules() -> [Module] {
        repositoryDefinitions.map { $0() }
    }
}
#else
public struct RepositoryModuleFactory: RepositoryModuleFactoryProtocol {
    // MARK: - 저장 프로퍼티

    /// 의존성 등록에 사용되는 헬퍼 객체입니다.
    public let registerModule = RegisterModule()

    /// Repository 모듈을 생성하는 클로저들의 배열입니다.
    public var repositoryDefinitions: [() -> Module]

    // MARK: - 초기화

    /// 생성자
    ///
    /// - Parameter repositoryDefinitions: 모듈 생성 클로저 배열을 전달할 수 있습니다.
    ///   만약 `nil`이 전달되면, 기본 의존성은 빈 배열로 초기화됩니다.
    public init(repositoryDefinitions: [() -> Module]? = nil) {
        self.repositoryDefinitions = repositoryDefinitions ?? []
    }

    // MARK: - 메서드

    /// `repositoryDefinitions` 배열의 모든 클로저를 실행하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    public func makeAllModules() -> [Module] {
        repositoryDefinitions.map { $0() }
    }
}
#endif
