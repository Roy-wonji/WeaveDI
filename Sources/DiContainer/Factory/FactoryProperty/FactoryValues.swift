//
//  FactoryValues.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/24/25.
//

import Foundation

#if swift(>=5.9)
@available(iOS 17.0, *)
/// `FactoryValues`는 애플리케이션 전역에서 사용할 팩토리 인스턴스들을 보관하는 구조체입니다.
///
/// - `repositoryFactory`: Repository 모듈 팩토리의 기본 인스턴스를 저장합니다.
/// - `useCaseFactory`: UseCase 모듈 팩토리의 기본 인스턴스를 저장합니다.
/// - `current`: 전역으로 접근 가능한 `FactoryValues`의 싱글턴 인스턴스입니다.
///
public struct FactoryValues {
    // MARK: - 팩토리 프로퍼티
    
    /// Repository 모듈 팩토리 기본 인스턴스
    public var repositoryFactory: RepositoryModuleFactory = RepositoryModuleFactory()
    
    /// UseCase 모듈 팩토리 기본 인스턴스
    public var useCaseFactory: UseCaseModuleFactory = UseCaseModuleFactory()
    
    // MARK: - 초기화
    
    /// 기본 생성자. 커스텀 설정이 필요 없을 때 사용합니다.
    public init() {}
    
    // MARK: - 전역 인스턴스
    
    /// 전역으로 사용 가능한 `FactoryValues` 싱글턴 인스턴스
    ///
    /// - 설명:
    ///   - `nonisolated(unsafe)`는 해당 프로퍼티가 액터 격리(actor isolation)를 우회하도록 허용합니다.
    ///   - iOS 17.0 이상 환경에서, 비동기 또는 액터 내부에서 동기 접근이 필요한 경우 안전하게 사용합니다.
    nonisolated(unsafe) static var current = FactoryValues()
}

#else

/// `FactoryValues`는 애플리케이션 전역에서 사용할 팩토리 인스턴스들을 보관하는 구조체입니다.
///
/// - `repositoryFactory`: Repository 모듈 팩토리의 기본 인스턴스를 저장합니다.
/// - `useCaseFactory`: UseCase 모듈 팩토리의 기본 인스턴스를 저장합니다.
/// - `current`: 전역으로 접근 가능한 `FactoryValues`의 싱글턴 인스턴스입니다.
///
public struct FactoryValues {
    // MARK: - 팩토리 프로퍼티
    
    /// Repository 모듈 팩토리 기본 인스턴스
    public var repositoryFactory: RepositoryModuleFactory = RepositoryModuleFactory()
    
    /// UseCase 모듈 팩토리 기본 인스턴스
    public var useCaseFactory: UseCaseModuleFactory = UseCaseModuleFactory()
    
    // MARK: - 초기화
    
    /// 기본 생성자. 커스텀 설정이 필요 없을 때 사용합니다.
    public init() {}
    
    // MARK: - 전역 인스턴스
    
    /// 전역으로 사용 가능한 `FactoryValues` 싱글턴 인스턴스
    ///
    /// - 설명:
    ///   - `nonisolated(unsafe)`를 사용하여, 액터 격리 제약을 우회하고 동기식으로 접근할 수 있도록 합니다.
    nonisolated(unsafe) static var current = FactoryValues()
}
#endif
