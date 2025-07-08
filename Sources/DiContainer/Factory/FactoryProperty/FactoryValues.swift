//
//  FactoryValues.swift
//  DiContainer
//
//  Created by Wonji Suh  on 3/24/25.
//

import Foundation

/// `FactoryValues`는 애플리케이션 전역에서 사용할 팩토리 인스턴스들을 보관하는 구조체입니다.
///
/// - `repositoryFactory`: Repository 모듈 팩토리의 기본 인스턴스를 저장합니다.
/// - `useCaseFactory`: UseCase 모듈 팩토리의 기본 인스턴스를 저장합니다.
/// - `current`: 전역으로 접근 가능한 `FactoryValues` 싱글턴 인스턴스입니다.
///
/// ## 설명
/// - `nonisolated(unsafe)`: 액터 격리(actor isolation)를 우회하여, 비동기/동기 환경을 가리지 않고 `FactoryValues.current`에 접근할 수 있도록 허용합니다.
/// - Swift 5.9 이상, iOS 17.0 이상 환경에서 안전하게 사용 가능합니다.
public struct FactoryValues {
    // MARK: - 팩토리 프로퍼티
    
    /// Repository 모듈 팩토리 기본 인스턴스
    public var repositoryFactory: RepositoryModuleFactory = RepositoryModuleFactory()
    
    /// UseCase 모듈 팩토리 기본 인스턴스
    public var useCaseFactory: UseCaseModuleFactory = UseCaseModuleFactory()
    
    // MARK: - 초기화
    
    /// 기본 생성자.
    /// - 설명: 별도 설정 없이 기본 팩토리 인스턴스를 사용하고자 할 때 호출합니다.
    public init() {}
    
    // MARK: - 전역 인스턴스
    
    /// 전역으로 사용 가능한 `FactoryValues` 싱글턴 인스턴스
    ///
    /// - 설명:
    ///   - `nonisolated(unsafe)`를 사용하여, 액터 격리 제약을 우회하고 동기/비동기 구분 없이 접근할 수 있도록 합니다.
    nonisolated(unsafe) static var current = FactoryValues()
}


/// `FactoryValues`는 애플리케이션 전역에서 사용할 팩토리 인스턴스들을 보관하는 구조체입니다.
///
/// - `repositoryFactory`: Repository 모듈 팩토리의 기본 인스턴스를 저장합니다.
/// - `useCaseFactory`: UseCase 모듈 팩토리의 기본 인스턴스를 저장합니다.
/// - `current`: 전역으로 접근 가능한 `FactoryValues` 싱글턴 인스턴스입니다.
///
/// ## 설명
/// - Swift 5.9 미만 또는 iOS 17.0 미지원 환경에서 사용 가능합니다.
/// - `nonisolated(unsafe)`를 사용하여 액터 격리 제약을 우회하고 동기적으로 접근할 수 있습니다.


// MARK: - 사용 예시 코드

/*
-----------------------------
 예시 1: 기본 FactoryValues 활용
-----------------------------
import Foundation

// 1) FactoryValues 확장: 추가 팩토리 등록
extension FactoryValues {
    /// 보조 API 팩토리
    var apiFactory: APIModuleFactory {
        APIModuleFactory()
    }
}

// 2) ViewModel 또는 클래스 내에서 @Factory 사용
class MyViewModel {
    // RepositoryModuleFactory 인스턴스를 current에서 주입받음
    @Factory(\.repositoryFactory)
    var repositoryFactory: RepositoryModuleFactory

    // UseCaseModuleFactory 인스턴스를 current에서 주입받음
    @Factory(\.useCaseFactory)
    var useCaseFactory: UseCaseModuleFactory

    // API 팩토리도 주입받고 싶다면 아래처럼 추가
    @Factory(\.apiFactory)
    var apiFactory: APIModuleFactory

    func configure() {
        // repositoryFactory.makeAllModules() 등을 호출해 모듈 생성
        let repoModules = repositoryFactory.makeAllModules()
        // useCaseFactory.makeAllModules() 등을 호출해 UseCase 모듈 생성
        let useCaseModules = useCaseFactory.makeAllModules()
        // apiFactory.makeAllModules() 등을 호출해 API 모듈 생성
        let apiModules = apiFactory.makeAllModules()

        // 생성된 모듈들을 Container에 등록하거나, 필요한 로직을 수행
        // ...
    }
}

-----------------------------
 예시 2: 런타임 중 FactoryValues 업데이트
-----------------------------
import Foundation

@main
struct MyApp {
    static func main() async {
        // 1) 기본 FactoryValues 사용 (DefaultRepositoryModuleFactory, DefaultUseCaseModuleFactory)
        print("초기 repositoryFactory:", FactoryValues.current.repositoryFactory)
        print("초기 useCaseFactory:", FactoryValues.current.useCaseFactory)

        // 2) 런타임에서 repositoryFactory를 교체
        FactoryValues.current.repositoryFactory = CustomRepositoryModuleFactory()
        FactoryValues.current.useCaseFactory = CustomUseCaseModuleFactory()

        // 3) 변경된 팩토리 사용
        print("변경 후 repositoryFactory:", FactoryValues.current.repositoryFactory)
        print("변경 후 useCaseFactory:", FactoryValues.current.useCaseFactory)

        // 4) ViewModel 등에서 @Factory를 사용해 최신 팩토리를 주입받음
        let vm = MyViewModel()
        vm.configure()
    }
}
*/
