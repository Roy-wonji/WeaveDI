//
//  QuickStartGuide.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation

/// # DiContainer 빠른 시작 가이드
///
/// 이 가이드는 DiContainer의 핵심 기능을 빠르게 익힐 수 있도록 구성되었습니다.
public enum QuickStartGuide {

    // MARK: - 1. 기본 등록 및 사용

    /// ## 1단계: 의존성 등록
    ///
    /// ```swift
    /// // 앱 시작 시 등록
    /// await DependencyContainer.bootstrap { container in
    ///     container.register(NetworkService.self) { DefaultNetworkService() }
    ///     container.register(UserRepository.self) { UserRepositoryImpl() }
    /// }
    /// ```
    public static let step1_registration = """
    Basic dependency registration using DependencyContainer.bootstrap
    """

    /// ## 2단계: 의존성 사용
    ///
    /// ```swift
    /// // 의존성 주입
    /// @Inject(\.userService) var userService: UserService?
    ///
    /// // 또는 직접 해결
    /// let service = DI.resolve(UserService.self)
    /// ```
    public static let step2_injection = """
    Use @Inject property wrapper or DI.resolve() for dependency injection
    """

    // MARK: - 2. 모듈 기반 등록

    /// ## 모듈을 사용한 구조화된 등록
    ///
    /// ```swift
    /// let factory = ModuleFactoryManager()
    /// factory.repositoryFactory.addRepository(UserRepository.self) { UserRepositoryImpl() }
    /// factory.useCaseFactory.addUseCase(UserUseCase.self,
    ///                                   repositoryType: UserRepository.self,
    ///                                   repositoryFallback: { MockUserRepository() })
    ///                                   { repo in UserUseCaseImpl(repository: repo) }
    /// await factory.registerAll()
    /// ```
    public static let step3_modules = """
    Use ModuleFactoryManager for structured, layered dependency registration
    """

    // MARK: - 3. 실제 사용 예시

    /// 실제 앱에서 사용하는 전체 예시
    public static func fullExample() {
        // 이 예시는 README.md나 문서에서 참조용으로만 사용
    }
}