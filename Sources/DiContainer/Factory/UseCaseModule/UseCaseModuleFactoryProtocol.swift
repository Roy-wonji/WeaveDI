//
//  UseCaseModuleFactoryProtocol.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/20/25.
//

import Foundation

/// `UseCaseModuleFactoryProtocol`은 Use Case 모듈을 생성 및 등록하기 위한 기본 인터페이스를 정의합니다.
/// 이 프로토콜을 채택하는 타입은 의존성 등록 헬퍼 객체(`registerModule`),
/// 모듈 생성 클로저 배열(`useCaseDefinitions`), 그리고 모든 모듈을 생성하는 기능(`makeAllModules()`)을 제공해야 합니다.
#if swift(>=5.9)
@available(iOS 17.0, *)
public protocol UseCaseModuleFactoryProtocol {
    // MARK: - 프로퍼티

    /// Use Case 모듈 생성 시 필요한 의존성을 등록하기 위한 헬퍼 객체
    var registerModule: RegisterModule { get }

    /// Use Case 모듈을 생성하는 클로저들의 배열.
    /// 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
    var useCaseDefinitions: [() -> Module] { get }

    // MARK: - 메서드

    /// `useCaseDefinitions` 배열에 있는 모든 클로저를 실행하여, 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    func makeAllModules() -> [Module]
}

#else
public protocol UseCaseModuleFactoryProtocol {
    // MARK: - 프로퍼티

    /// Use Case 모듈 생성 시 필요한 의존성을 등록하기 위한 헬퍼 객체
    var registerModule: RegisterModule { get }

    /// Use Case 모듈을 생성하는 클로저들의 배열.
    /// 각 클로저는 호출 시 `Module` 인스턴스를 반환합니다.
    var useCaseDefinitions: [() -> Module] { get }

    // MARK: - 메서드

    /// `useCaseDefinitions` 배열에 있는 모든 클로저를 실행하여, 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    func makeAllModules() -> [Module]
}
#endif

/// `UseCaseModuleFactoryProtocol`의 기본 구현을 제공하는 `extension`입니다.
/// `makeAllModules()` 메서드는 `useCaseDefinitions` 배열에 있는 모든 클로저를 순회하며 실행합니다.
#if swift(>=5.9)
@available(iOS 17.0, *)
public extension UseCaseModuleFactoryProtocol {
    /// `useCaseDefinitions` 배열의 모든 클로저를 호출하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    func makeAllModules() -> [Module] {
        useCaseDefinitions.map { $0() }
    }
}
#else
public extension UseCaseModuleFactoryProtocol {
    /// `useCaseDefinitions` 배열의 모든 클로저를 호출하여 생성된 `Module` 인스턴스들의 배열을 반환합니다.
    ///
    /// - Returns: 생성된 `Module` 인스턴스들의 배열
    func makeAllModules() -> [Module] {
        useCaseDefinitions.map { $0() }
    }
}
#endif
