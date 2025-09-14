//
//  ContainerDocumentation.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/19/25.
//

import Foundation

// MARK: - Container Usage Examples and Documentation

/// **Module** 은 DI 컨테이너에 "등록 작업"을 수행하기 위한 **최소 단위**입니다.
/// (이 파일에는 타입 정의가 없고, 외부에서 제공되는 `public actor Module`을 사용합니다.)
///
/// # Overview
/// - 생성 예: `Module(MyServiceProtocol.self) { DefaultMyService() }`
/// - 역할: 내부에 캡슐화된 등록 클로저를 `register()` 호출 시 실행하여
///   `DependencyContainer.live.register(type, build: factory)` 를 수행합니다.
/// - 반환값/오류: `register()` 는 `async` 이며 `Void`를 반환합니다(throw 하지 않음).
///
/// # Example
/// ```swift
/// // 1) 모듈 생성
/// let repoModule = Module(RepositoryProtocol.self) { DefaultRepository() }
/// let useCaseModule = Module(UseCaseProtocol.self) { DefaultUseCase(repo: DefaultRepository()) }
///
/// // 2) 컨테이너에 모듈 추가
/// let container = Container()
/// container.register(repoModule)
/// container.register(useCaseModule)
///
/// // 3) 병렬 등록 수행
/// await container.build()
/// ```
public enum ContainerUsageExamples {

    // MARK: - 기본 사용 패턴

    /// ## 기본 사용 패턴
    ///
    /// ### 1단계: 컨테이너 생성 및 모듈 수집
    /// ```swift
    /// let container = Container()
    ///
    /// // 모듈 개별 등록
    /// container.register(userRepositoryModule)
    /// container.register(authServiceModule)
    /// container.register(networkServiceModule)
    /// ```
    ///
    /// ### 2단계: 체이닝을 통한 연속 등록
    /// ```swift
    /// let container = Container()
    ///     .register(userRepositoryModule)
    ///     .register(authServiceModule)
    ///     .register(networkServiceModule)
    /// ```
    ///
    /// ### 3단계: 일괄 등록 실행
    /// ```swift
    /// // 모든 모듈을 병렬로 등록
    /// await container.build()
    /// ```
    public static let basicUsage = """
    Basic usage patterns for Container module registration and parallel execution.
    """

    // MARK: - 고급 사용 패턴

    /// ## 고급 사용 패턴
    ///
    /// ### Factory 패턴과의 연동
    /// ```swift
    /// let container = Container()
    /// let repositoryFactory = RepositoryModuleFactory()
    /// let useCaseFactory = UseCaseModuleFactory()
    ///
    /// // Factory에서 생성된 모듈들을 일괄 등록
    /// await repositoryFactory.makeAllModules().asyncForEach { module in
    ///     await container.register(module)
    /// }
    ///
    /// await useCaseFactory.makeAllModules().asyncForEach { module in
    ///     await container.register(module)
    /// }
    ///
    /// // 모든 모듈을 병렬 등록
    /// await container.build()
    /// ```
    ///
    /// ### 조건부 모듈 등록
    /// ```swift
    /// let container = Container()
    ///
    /// // 환경에 따른 조건부 등록
    /// if ProcessInfo.processInfo.environment["ENABLE_ANALYTICS"] == "true" {
    ///     container.register(analyticsModule)
    /// }
    ///
    /// #if DEBUG
    /// container.register(debugLoggingModule)
    /// #else
    /// container.register(productionLoggingModule)
    /// #endif
    ///
    /// await container.build()
    /// ```
    ///
    /// ### 클로저를 활용한 구성
    /// ```swift
    /// let container = Container()
    ///
    /// container {
    ///     // 클로저 내부에서 추가 설정
    ///     print("모듈 등록 준비 완료")
    /// }
    /// .register(module1)
    /// .register(module2)
    ///
    /// await container.build()
    /// ```
    public static let advancedUsage = """
    Advanced usage patterns including factory integration and conditional registration.
    """

    // MARK: - 성능 최적화 가이드

    /// ## 성능 최적화 팁
    ///
    /// ### 1. 모듈 그룹화
    /// ```swift
    /// // ✅ 좋은 예: 논리적 그룹별로 분할
    /// await coreContainer.build()      // 핵심 의존성 먼저
    /// await featureContainer.build()   // 기능별 의존성 나중에
    /// ```
    ///
    /// ### 2. 의존성 순서 고려
    /// ```swift
    /// // ✅ 의존성이 있는 경우 단계별 등록
    /// await basicContainer.build()     // 기본 의존성
    /// await dependentContainer.build() // 위에 의존하는 것들
    /// ```
    ///
    /// ### 3. 메모리 사용량 모니터링
    /// ```swift
    /// let memoryBefore = getMemoryUsage()
    /// await container.build()
    /// let memoryAfter = getMemoryUsage()
    /// print("메모리 사용량 증가: \(memoryAfter - memoryBefore)MB")
    /// ```
    public static let performanceOptimization = """
    Performance optimization tips for large-scale module registration.
    """

    // MARK: - 제한사항 및 고려사항

    /// ## 제한사항 및 고려사항
    ///
    /// ### ⚠️ 의존성 순서
    /// 이 컨테이너는 의존성 간의 순서를 보장하지 않습니다. 순서가 중요한 경우:
    ///
    /// ```swift
    /// // ❌ 문제 상황: B가 A에 의존하지만 순서 보장 없음
    /// container.register(moduleB) // A가 필요하지만 아직 등록되지 않을 수 있음
    /// container.register(moduleA)
    ///
    /// // ✅ 해결책 1: 모듈 팩토리에서 의존성 해결
    /// let moduleB = registerModule.makeDependency(BProtocol.self) {
    ///     let a = DependencyContainer.live.resolve(AProtocol.self)!
    ///     return BImplementation(dependency: a)
    /// }
    ///
    /// // ✅ 해결책 2: 별도의 순서 보장 로직 사용
    /// await container.register(moduleA).build() // A 먼저 등록
    /// await Container().register(moduleB).build() // B 나중에 등록
    /// ```
    ///
    /// ### ⚠️ 오류 처리
    /// 현재 구현에서는 모듈 등록 실패를 개별적으로 처리하지 않습니다:
    ///
    /// ```swift
    /// // 현재: 모든 모듈이 성공하거나 일부 실패해도 계속 진행
    /// await container.build() // throws 하지 않음
    ///
    /// // 향후 확장 가능: 오류 수집 및 보고
    /// // let failures = try await container.buildWithErrorHandling()
    /// ```
    public static let limitationsAndConsiderations = """
    Important limitations and considerations when using Container.
    """
}

// MARK: - Performance Characteristics Documentation

/// Container 성능 특성에 대한 상세 문서
public enum ContainerPerformanceGuide {

    /// ## 병렬 처리 최적화
    /// - **동시 실행**: 독립적인 모듈들이 병렬로 등록되어 전체 시간 단축
    /// - **메모리 효율**: 스냅샷 방식으로 불필요한 메모리 복사 최소화
    /// - **CPU 활용**: 멀티코어 환경에서 모든 코어 활용 가능
    ///
    /// ### 메모리 관리
    /// ```swift
    /// // 등록 완료 후 내부 모듈 배열은 자동으로 해제됨
    /// await container.build() // 이후 modules 배열은 비워짐
    /// ```
    public static let parallelProcessingOptimization = """
    Detailed explanation of parallel processing optimizations in Container.
    """

    /// ## 동시성 모델
    ///
    /// ### Actor 기반 안전성
    /// - 내부 상태 변경은 actor의 직렬 실행 큐에서만 발생
    /// - 외부에서의 동시 접근이 자동으로 동기화됨
    /// - 데이터 경쟁 조건 완전 차단
    ///
    /// ### Task Group 활용
    /// ```swift
    /// // 내부 구현 예시 (실제 코드)
    /// await withTaskGroup(of: Void.self) { group in
    ///     for module in modules {
    ///         group.addTask { @Sendable in
    ///             await module.register() // 각 모듈이 병렬 등록
    ///         }
    ///     }
    ///     await group.waitForAll() // 모든 등록 완료까지 대기
    /// }
    /// ```
    public static let concurrencyModel = """
    Concurrency model and thread safety guarantees of Container.
    """
}